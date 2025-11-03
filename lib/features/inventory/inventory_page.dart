import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../providers/inventory_provider.dart';
import '../../models/product.dart';
import '../../models/stock_alert.dart';
import '../../widgets/common/error_display.dart';
import '../../services/api_service.dart';
import 'widgets/stock_level_card.dart';
import 'widgets/stock_entry_dialog.dart';
import 'widgets/bulk_stock_take_dialog.dart';
import 'widgets/inventory_stats_cards.dart';
import 'widgets/invoice_upload_dialog.dart';
import 'widgets/pending_invoices_dialog.dart';

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inventoryProvider.notifier).refreshAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Product> _filterProducts(List<Product> products) {
    if (_searchQuery.isEmpty) return products;
    
    final query = _searchQuery.toLowerCase().trim();
    
    // Handle special stock-based searches
    if (query == 'in stock') {
      return _getInStockProducts(products)
        ..sort((a, b) => (b.stockLevel ?? 0).compareTo(a.stockLevel ?? 0)); // Sort by stock level descending
    }
    
    if (query == 'out of stock') {
      return _getOutOfStockProducts(products)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())); // Sort alphabetically
    }
    
    return products.where((product) {
      final name = product.name.toLowerCase();
      final sku = product.sku?.toLowerCase() ?? '';
      final department = product.department?.toLowerCase() ?? '';
      final unit = product.unit?.toLowerCase() ?? '';
      
      // Enhanced search: name, SKU, department, unit, and word-based matching
      return name.contains(query) || 
             sku.contains(query) ||
             department.contains(query) ||
             unit.contains(query) ||
             _matchesWords(name, query) ||
             _matchesWords(department, query);
    }).toList()
      ..sort((a, b) {
        // Sort by relevance: exact matches first, then starts with, then contains
        final aName = a.name.toLowerCase();
        final bName = b.name.toLowerCase();
        
        if (aName == query) return -1;
        if (bName == query) return 1;
        if (aName.startsWith(query)) return -1;
        if (bName.startsWith(query)) return 1;
        
        return aName.compareTo(bName);
      });
  }
  
  bool _matchesWords(String text, String query) {
    // Split query into words and check if all words are found in text
    final queryWords = query.split(' ').where((w) => w.isNotEmpty).toList();
    if (queryWords.isEmpty) return false;
    
    return queryWords.every((word) => text.contains(word));
  }

  List<Product> _getInStockProducts(List<Product> products) {
    return products.where((product) => 
      product.stockLevel != null && product.stockLevel! > 0
    ).toList();
  }

  List<Product> _getOutOfStockProducts(List<Product> products) {
    return products.where((product) => 
      product.stockLevel == null || product.stockLevel! <= 0
    ).toList();
  }

  Widget _buildQuickSearchChip(String label) {
    // Choose appropriate icon based on label
    IconData icon;
    Color chipColor;
    
    switch (label.toLowerCase()) {
      case 'in stock':
        icon = Icons.check_circle;
        chipColor = Colors.green.withOpacity(0.2);
        break;
      case 'out of stock':
        icon = Icons.remove_circle;
        chipColor = Colors.red.withOpacity(0.2);
        break;
      case 'herbs':
        icon = Icons.eco;
        chipColor = const Color(0xFF2D5016).withOpacity(0.2);
        break;
      case 'vegetables':
        icon = Icons.grass;
        chipColor = const Color(0xFF2D5016).withOpacity(0.2);
        break;
      case 'fruits':
        icon = Icons.apple;
        chipColor = Colors.orange.withOpacity(0.2);
        break;
      default:
        icon = Icons.search;
        chipColor = const Color(0xFF2D5016).withOpacity(0.2);
    }
    
    return InkWell(
      onTap: () {
        setState(() {
          _searchQuery = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: chipColor.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: Colors.grey.shade300,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventoryState = ref.watch(inventoryProvider);
    print('[INVENTORY_UI] Building with ${inventoryState.stockAlerts.length} alerts in state');

    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Very dark background like dashboard
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/karl-dashboard'),
        ),
        title: const Text('Inventory Management'),
        backgroundColor: const Color(0xFF2D5016), // Dark green AppBar to match dashboard
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            tooltip: 'Compare with Previous Stock Take',
            onPressed: () => _compareWithPreviousStock(context),
          ),
          IconButton(
            icon: const Icon(Icons.update),
            tooltip: 'Apply WhatsApp Stock Updates',
            onPressed: () => _applyWhatsAppStockUpdates(context),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Invoice Processing',
            onPressed: () => _showInvoiceProcessingMenu(context),
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _showPrintPreview(context, inventoryState.products),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(inventoryProvider.notifier).refreshAll(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All Stock', icon: Icon(Icons.inventory)),
            Tab(text: 'Low Stock', icon: Icon(Icons.warning)),
            Tab(text: 'Alerts', icon: Icon(Icons.notifications)),
            Tab(text: 'Movements', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Stats Cards
          const InventoryStatsCards(),
          
          // Enhanced Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade800,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name, department, unit, SKU, or try "In Stock"...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white70),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF2D2D2D),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2D5016), width: 2),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                if (_searchQuery.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Searching in names, departments, units, and SKUs. Results sorted by relevance.',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  // Quick search suggestions
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildQuickSearchChip('In Stock'),
                      _buildQuickSearchChip('Out of Stock'),
                      _buildQuickSearchChip('Herbs'),
                      _buildQuickSearchChip('Vegetables'),
                      _buildQuickSearchChip('Fruits'),
                      _buildQuickSearchChip('kg'),
                      _buildQuickSearchChip('packet'),
                      _buildQuickSearchChip('punnet'),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: inventoryState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : inventoryState.error != null
                    ? ErrorDisplay(
                        message: inventoryState.error!,
                        onRetry: () => ref.read(inventoryProvider.notifier).refreshAll(),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          // All Stock Tab
                          _buildProductsList(_filterProducts(inventoryState.products)),
                          
                          // Low Stock Tab
                          _buildProductsList(_filterProducts(inventoryState.lowStockProducts)),
                          
                          // Alerts Tab
                          _buildAlertsTab(inventoryState.stockAlerts),
                          
                          // Movements Tab
                          _buildMovementsTab(inventoryState.stockMovements),
                        ],
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStockEntryMenu(context),
        icon: const Icon(Icons.add),
        label: const Text('Stock Entry'),
      ),
    );
  }

  Widget _buildProductsList(List<Product> products) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'No products found for "$_searchQuery"'
                  : 'No products found',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Try searching for department, unit, or partial name',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear Search'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D5016),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search results header
        if (_searchQuery.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2D5016).withOpacity(0.1),
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade800,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 8),
                Text(
                  '${products.length} result${products.length == 1 ? '' : 's'} for "$_searchQuery"',
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
          ),
        
        // Products list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              // Convert Product to Map for compatibility with existing StockLevelCard
              final item = {
                'id': product.id,
                'product_id': product.id,
                'product_name': product.name,
                'sku': product.sku ?? '',
                'current_stock': product.stockLevel,
                'minimum_stock': product.minimumStock,
                'unit': product.unit,
                'unit_price': product.price,
                'department': product.department,
              };
              return StockLevelCard(
                item: item,
                onAdjustStock: () => _showStockEntryDialog(context, product),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlertsTab(List<StockAlert> alerts) {
    print('[INVENTORY_UI] Building alerts tab with ${alerts.length} alerts');
    
    if (alerts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('No active alerts', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text('Check console logs for loading issues', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final alert = alerts[index];
        
        return Card(
          child: ListTile(
            leading: Icon(
              Icons.warning,
              color: _getAlertSeverityColor(alert.severity),
            ),
            title: Text(alert.alertTypeDisplay),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.message),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getAlertSeverityColor(alert.severity).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        alert.severityDisplay,
                        style: TextStyle(
                          fontSize: 11,
                          color: _getAlertSeverityColor(alert.severity),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (alert.productName != null)
                      Text(
                        alert.productName!,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditAlertDialog(context, alert),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMovementsTab(List<Map<String, dynamic>> movements) {
    if (movements.isEmpty) {
      return const Center(
        child: Text('No stock movements found'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: movements.length,
      itemBuilder: (context, index) {
        final movement = movements[index];
        final isIncrease = (movement['quantity'] as num?) != null && (movement['quantity'] as num) > 0;
        
        return Card(
          child: ListTile(
            leading: Icon(
              isIncrease ? Icons.add_circle : Icons.remove_circle,
              color: isIncrease ? Colors.green : Colors.red,
            ),
            title: Text(movement['product_name'] ?? 'Unknown Product'),
            subtitle: Text(
              '${movement['movement_type'] ?? 'Movement'} • ${movement['created_at'] ?? ''}',
            ),
            trailing: Text(
              '${isIncrease ? '+' : ''}${movement['quantity'] ?? 0}',
              style: TextStyle(
                color: isIncrease ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }



  void _showStockEntryMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Stock Entry Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.inventory_2),
              title: const Text('Individual Stock Entry'),
              subtitle: const Text('Adjust stock for a single product'),
              onTap: () {
                Navigator.pop(context);
                _showProductSelector(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Bulk Stock Take'),
              subtitle: const Text('Count and update multiple products'),
              onTap: () {
                Navigator.pop(context);
                _showBulkStockTake(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning),
              title: const Text('Low Stock Items'),
              subtitle: const Text('Focus on items needing attention'),
              onTap: () {
                Navigator.pop(context);
                _showLowStockEntry(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.green),
              title: const Text('Apply WhatsApp Stock Updates'),
              subtitle: const Text('Apply parsed stock from WhatsApp messages'),
              onTap: () {
                Navigator.pop(context);
                _applyWhatsAppStockUpdates(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showProductSelector(BuildContext context) {
    final inventoryState = ref.read(inventoryProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Product'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: inventoryState.products.length,
            itemBuilder: (context, index) {
              final product = inventoryState.products[index];
              return ListTile(
                title: Text(product.name),
                subtitle: Text('Current: ${product.stockLevel.toStringAsFixed(2)} ${product.unit}'),
                trailing: product.stockLevel <= product.minimumStock
                    ? const Icon(Icons.warning, color: Colors.orange)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  _showStockEntryDialog(context, product);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showStockEntryDialog(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (context) => StockEntryDialog(
        product: product,
        currentStock: product.stockLevel,
      ),
    );
  }

  void _showBulkStockTake(BuildContext context) {
    final inventoryState = ref.read(inventoryProvider);
    
    // Filter to only show products with stock > 0 (users can still search and add others)
    final productsWithStock = inventoryState.products.where((product) {
      return product.stockLevel > 0;
    }).toList();
    
    if (productsWithStock.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No products with stock found. Use search to add products.'),
          backgroundColor: Colors.orange,
        ),
      );
      // Still show dialog even if empty - users can search and add products
    }
    
    showDialog(
      context: context,
      builder: (context) => BulkStockTakeDialog(
        products: productsWithStock,
      ),
    );
  }

  void _showLowStockEntry(BuildContext context) {
    final inventoryState = ref.read(inventoryProvider);
    final lowStockProducts = inventoryState.products.where((product) {
      return product.stockLevel > 0 && product.stockLevel <= product.minimumStock;
    }).toList();
    
    if (lowStockProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No low stock items found'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => BulkStockTakeDialog(
        products: lowStockProducts,
      ),
    );
  }

  Color _getAlertSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.yellow;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _showEditAlertDialog(BuildContext context, StockAlert alert) {
    showDialog(
      context: context,
      builder: (context) => _EditAlertDialog(alert: alert),
    );
  }

  void _showInvoiceProcessingMenu(BuildContext context) async {
    try {
      // Check invoice upload status
      final apiService = ref.read(apiServiceProvider);
      final statusResponse = await apiService.getInvoiceUploadStatus();
      
      if (!context.mounted) return;
      
      final status = statusResponse['status'] ?? 'ready_for_upload';
      final buttonText = statusResponse['button_text'] ?? 'Upload Invoices for Day';
      final action = statusResponse['action'] ?? 'upload_invoices';
      
      showModalBottomSheet(
        context: context,
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long, color: Color(0xFF2D5016)),
                  const SizedBox(width: 8),
                  const Text(
                    'Invoice Processing',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Main action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: action == 'wait' ? null : () {
                    Navigator.pop(context);
                    if (action == 'upload_invoices') {
                      _showInvoiceUpload(context);
                    } else if (action == 'process_stock') {
                      _processStockReceived(context);
                    }
                  },
                  icon: Icon(_getActionIcon(action)),
                  label: Text(buttonText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D5016),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Secondary actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showPendingInvoices(context);
                      },
                      icon: const Icon(Icons.list),
                      label: const Text('View Pending'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2D5016),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showInvoiceHistory(context);
                      },
                      icon: const Icon(Icons.history),
                      label: const Text('History'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2D5016),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking invoice status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ready_for_upload':
        return Colors.blue;
      case 'invoices_pending':
        return Colors.orange;
      case 'ready_for_stock_processing':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'upload_invoices':
        return Icons.upload;
      case 'process_stock':
        return Icons.inventory;
      case 'wait':
        return Icons.hourglass_empty;
      default:
        return Icons.help;
    }
  }

  void _showInvoiceUpload(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const InvoiceUploadDialog(),
    );
  }

  void _showPendingInvoices(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const PendingInvoicesDialog(),
    );
  }

  void _showInvoiceHistory(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invoice history feature coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _processStockReceived(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Processing stock received...'),
            ],
          ),
        ),
      );

      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.processStockReceived();
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Stock processed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh inventory
        ref.read(inventoryProvider.notifier).refreshAll();
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing stock: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _compareWithPreviousStock(BuildContext context) async {
    debugPrint('🔧 _compareWithPreviousStock called');
    
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Comparing stock levels...'),
            ],
          ),
        ),
      );

      // Get comparison data
      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.compareStockWithPrevious();
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        if (result['status'] == 'success') {
          // Show comparison results dialog
          await showDialog(
            context: context,
            builder: (context) => _StockComparisonDialog(
              comparisonData: result,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to compare stock'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error comparing stock: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyWhatsAppStockUpdates(BuildContext context) async {
    debugPrint('🔧 _applyWhatsAppStockUpdates called');
    
    // Show stock take options dialog
    final bool? resetStock = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply WhatsApp Stock Updates'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How do you want to apply the stock updates?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            const Text(
              '🎯 Complete Stock Take (Recommended)',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const Text(
              '• Reset all stock to 0 first\n'
              '• Apply new stock levels from WhatsApp\n'
              '• Ensures accurate physical count',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            const Text(
              '⚠️ Additive Update (Use with caution)',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            const Text(
              '• Keep existing stock levels\n'
              '• Add/update only items in WhatsApp message\n'
              '• May lead to incorrect stock levels',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint('🔧 User cancelled stock update');
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () {
              debugPrint('🔧 User selected Additive Update');
              Navigator.of(context).pop(false);
            },
            child: const Text('Additive Update'),
          ),
          ElevatedButton(
            onPressed: () {
              debugPrint('🔧 User selected Complete Stock Take');
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete Stock Take'),
          ),
        ],
      ),
    );

    if (resetStock == null) {
      debugPrint('🔧 User cancelled, returning');
      return; // User cancelled
    }

    debugPrint('🔧 Starting stock update process with resetStock: $resetStock');

    // Check if context is still valid before proceeding
    if (!context.mounted) {
      debugPrint('🔧 Context no longer mounted, aborting');
      return;
    }

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text(resetStock 
                ? 'Processing complete stock take...' 
                : 'Applying additive stock updates...'),
            ],
          ),
        ),
      );

      debugPrint('🔧 Calling API service...');
      // Apply stock updates
      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.applyStockUpdatesToInventory(
        resetBeforeProcessing: resetStock,
      );
      
      debugPrint('🔧 API result: $result');
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      debugPrint('🔧 Refreshing inventory data...');
      // Refresh inventory data
      await ref.read(inventoryProvider.notifier).refreshAll();

      if (context.mounted) {
        // Handle the response structure properly
        final successRate = result['success_rate'] ?? 0;
        final totalItems = result['total_items_processed'] ?? 0;
        final successfulItems = result['successful_items'] ?? 0;
        final failedItems = result['failed_items'] ?? [];
        final errors = result['errors'] ?? [];
        final warnings = result['warnings'] ?? [];

        String message = result['message'] ?? 'Stock updates applied successfully';
        message += '\n\nSuccess Rate: ${successRate}%';
        message += '\nProcessed: $successfulItems/$totalItems items';
        
        if (failedItems.isNotEmpty) {
          message += '\n\nFailed Items:';
          for (var item in failedItems.take(3)) {
            message += '\n• ${item['original_name']}: ${item['failure_reason']}';
          }
          if (failedItems.length > 3) {
            message += '\n• ... and ${failedItems.length - 3} more';
          }
        }

        if (errors.isNotEmpty) {
          message += '\n\nErrors: ${errors.join(', ')}';
        }

        if (warnings.isNotEmpty) {
          message += '\n\nWarnings: ${warnings.join(', ')}';
        }

        debugPrint('🔧 Showing result message: $message');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: successRate >= 90 ? Colors.green : (successRate >= 70 ? Colors.orange : Colors.red),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      debugPrint('🔧 Error in stock update: $e');
      // Close loading dialog if still open
      if (context.mounted) {
        try {
          Navigator.of(context).pop();
        } catch (popError) {
          debugPrint('🔧 Error popping dialog: $popError');
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error applying stock updates: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showPrintPreview(BuildContext context, List<Product> products) {
    showDialog(
      context: context,
      builder: (context) => _StockReportDialog(products: products),
    );
  }
}

class _EditAlertDialog extends StatefulWidget {
  final StockAlert alert;

  const _EditAlertDialog({required this.alert});

  @override
  State<_EditAlertDialog> createState() => _EditAlertDialogState();
}

class _EditAlertDialogState extends State<_EditAlertDialog> {
  late TextEditingController _messageController;
  late String _selectedSeverity;
  late bool _isActive;
  late bool _isAcknowledged;

  final List<String> _severityOptions = ['low', 'medium', 'high', 'critical'];

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: widget.alert.message);
    _selectedSeverity = widget.alert.severity;
    _isActive = widget.alert.isActive;
    _isAcknowledged = widget.alert.isAcknowledged ?? false;
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.alert.alertTypeDisplay}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Alert Type (read-only)
            Text(
              'Alert Type: ${widget.alert.alertTypeDisplay}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),

            // Product (read-only if exists)
            if (widget.alert.productName != null) ...[
              Text(
                'Product: ${widget.alert.productName}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
            ],

            // Message
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Alert Message',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Severity
            DropdownButtonFormField<String>(
              initialValue: _selectedSeverity,
              decoration: const InputDecoration(
                labelText: 'Severity',
                border: OutlineInputBorder(),
              ),
              items: _severityOptions.map((severity) {
                return DropdownMenuItem(
                  value: severity,
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 12,
                        color: _getAlertSeverityColor(severity),
                      ),
                      const SizedBox(width: 8),
                      Text(severity.toUpperCase()),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedSeverity = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Status switches
            SwitchListTile(
              title: const Text('Active'),
              subtitle: const Text('Whether this alert is currently active'),
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),

            SwitchListTile(
              title: const Text('Acknowledged'),
              subtitle: const Text('Mark as acknowledged/resolved'),
              value: _isAcknowledged,
              onChanged: (value) {
                setState(() {
                  _isAcknowledged = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveAlert,
          child: const Text('Save Changes'),
        ),
      ],
    );
  }

  Color _getAlertSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.yellow;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _saveAlert() {
    // TODO: Implement API call to update alert
    // For now, just show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Alert updated successfully'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop();
  }
}

class _StockReportDialog extends StatelessWidget {
  final List<Product> products;

  const _StockReportDialog({required this.products});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final reportDate = '${now.day}/${now.month}/${now.year}';
    final reportTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    // FILTER: Only show products with stock > 0 for printing
    final inStockProducts = products.where((p) => p.stockLevel > 0).toList();
    
    // Calculate totals (only for in-stock items)
    final totalProducts = inStockProducts.length;
    final goodStockProducts = inStockProducts.where((p) => p.stockLevel > p.minimumStock).length;
    final lowStockProducts = inStockProducts.where((p) => p.stockLevel <= p.minimumStock).length;
    final outOfStockProducts = products.where((p) => p.stockLevel <= 0).length; // Show count but don't print
    final totalValue = inStockProducts.fold<double>(0.0, (sum, p) => sum + (p.stockLevel * p.price));

    return AlertDialog(
      title: const Text('Stock Report Preview'),
      content: SizedBox(
        width: 600,
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Report Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2D5016),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FAMBRI FARMS - STOCK ON HAND REPORT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Generated: $reportDate at $reportTime',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Summary Stats
            Row(
              children: [
                Expanded(child: _buildSummaryCard('In Stock', totalProducts.toString(), Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: _buildSummaryCard('Good Stock', goodStockProducts.toString(), Colors.green)),
                const SizedBox(width: 8),
                Expanded(child: _buildSummaryCard('Low Stock', lowStockProducts.toString(), Colors.orange)),
                const SizedBox(width: 8),
                Expanded(child: _buildSummaryCard('Out of Stock', outOfStockProducts.toString(), Colors.red)),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Stock Value:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'R${totalValue.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF2D5016),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Product List Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Current Stock', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Min Stock', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Value', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            
            // Product List (only in-stock items)
            Expanded(
              child: ListView.builder(
                itemCount: inStockProducts.length,
                itemBuilder: (context, index) {
                  final product = inStockProducts[index];
                  final value = product.stockLevel * product.price;
                  final status = product.stockLevel <= 0 
                      ? 'OUT' 
                      : product.stockLevel <= product.minimumStock 
                          ? 'LOW' 
                          : 'OK';
                  final statusColor = product.stockLevel <= 0 
                      ? Colors.red 
                      : product.stockLevel <= product.minimumStock 
                          ? Colors.orange 
                          : Colors.green;
                  
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            product.name,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${product.stockLevel.toStringAsFixed(1)} ${product.unit}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${product.minimumStock.toStringAsFixed(1)} ${product.unit}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'R${value.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton.icon(
          onPressed: () => _printStockReport(context, inStockProducts, reportDate, reportTime, totalValue, goodStockProducts, lowStockProducts),
          icon: const Icon(Icons.print),
          label: const Text('Print Report'),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  static Future<void> _printStockReport(
    BuildContext context,
    List<Product> inStockProducts,
    String reportDate,
    String reportTime,
    double totalValue,
    int goodStockProducts,
    int lowStockProducts,
  ) async {
    try {
      // Generate filename with current date
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final filename = 'FambriStock_$dateStr.pdf';
      
      await Printing.layoutPdf(
        name: filename,
        onLayout: (PdfPageFormat format) async {
          final pdf = pw.Document();
          
          // Split products into pages (30 items per page)
          const itemsPerPage = 30;
          final totalPages = (inStockProducts.length / itemsPerPage).ceil();
          
          for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
            final startIndex = pageIndex * itemsPerPage;
            final endIndex = (startIndex + itemsPerPage).clamp(0, inStockProducts.length);
            final pageProducts = inStockProducts.sublist(startIndex, endIndex);
            final isFirstPage = pageIndex == 0;
            final isLastPage = pageIndex == totalPages - 1;
            
            pdf.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                margin: const pw.EdgeInsets.all(20),
                build: (pw.Context context) {
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Header (only on first page)
                      if (isFirstPage) ...[
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.all(12),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#2D5016'),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'FAMBRI FARMS - STOCK ON HAND REPORT',
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                'Generated: $reportDate at $reportTime',
                                style: const pw.TextStyle(
                                  color: PdfColors.grey300,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 12),
                        
                        // Summary Stats
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('In Stock: ${inStockProducts.length}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                            pw.Text('Good Stock: $goodStockProducts', style: const pw.TextStyle(fontSize: 10, color: PdfColors.green)),
                            pw.Text('Low Stock: $lowStockProducts', style: const pw.TextStyle(fontSize: 10, color: PdfColors.orange)),
                          ],
                        ),
                        pw.SizedBox(height: 12),
                      ],
                      
                      // Page indicator (if multiple pages)
                      if (totalPages > 1) ...[
                        pw.Text(
                          'Page ${pageIndex + 1} of $totalPages',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                        ),
                        pw.SizedBox(height: 8),
                      ],
                      
                      // Table Header
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey300,
                        ),
                        child: pw.Row(
                          children: [
                            pw.Expanded(flex: 4, child: pw.Text('Product', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                            pw.Expanded(flex: 2, child: pw.Text('Current Stock', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                            pw.Expanded(flex: 2, child: pw.Text('Min Stock', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                            pw.Expanded(flex: 1, child: pw.Text('Status', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                          ],
                        ),
                      ),
                      
                      // Product Rows
                      ...pageProducts.map((product) {
                        final value = product.stockLevel * product.price;
                        final status = product.stockLevel <= product.minimumStock ? 'LOW' : 'OK';
                        
                        return pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
                          ),
                          child: pw.Row(
                            children: [
                              pw.Expanded(
                                flex: 4,
                                child: pw.Text(product.name, style: const pw.TextStyle(fontSize: 8)),
                              ),
                              pw.Expanded(
                                flex: 2,
                                child: pw.Text('${product.stockLevel.toStringAsFixed(1)} ${product.unit}', style: const pw.TextStyle(fontSize: 8)),
                              ),
                              pw.Expanded(
                                flex: 2,
                                child: pw.Text('${product.minimumStock.toStringAsFixed(1)} ${product.unit}', style: const pw.TextStyle(fontSize: 8)),
                              ),
                              pw.Expanded(
                                flex: 1,
                                child: pw.Text(
                                  status,
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                    color: status == 'LOW' ? PdfColors.orange : PdfColors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      
                      pw.Spacer(),
                      
                      // Footer
                      if (isLastPage) ...[
                        pw.Divider(),
                        pw.SizedBox(height: 8),
                        pw.Center(
                          child: pw.Text(
                            'End of Stock Report - Only items with stock > 0 are shown',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                          ),
                        ),
                      ] else ...[
                        pw.SizedBox(height: 8),
                        pw.Center(
                          child: pw.Text(
                            'Continued on next page...',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            );
          }
          
          return pdf.save();
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _StockComparisonDialog extends StatelessWidget {
  final Map<String, dynamic> comparisonData;

  const _StockComparisonDialog({
    required this.comparisonData,
  });

  @override
  Widget build(BuildContext context) {
    final summary = comparisonData['summary'] ?? {};
    final comparisonList = List<Map<String, dynamic>>.from(comparisonData['comparison_data'] ?? []);
    final currentDate = comparisonData['current_stock_date'] ?? '';
    final previousDate = comparisonData['previous_stock_date'] ?? '';

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.compare_arrows, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Stock Comparison Report',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),

            // Date Range
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.date_range, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Comparing: $previousDate → $currentDate',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Products',
                    '${summary['total_products'] ?? 0}',
                    Icons.inventory,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    'Unchanged',
                    '${summary['unchanged'] ?? 0}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    'Major Changes',
                    '${summary['major_changes'] ?? 0}',
                    Icons.warning,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    'Mismatches',
                    '${summary['inventory_mismatches'] ?? 0}',
                    Icons.error,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Comparison List
            Expanded(
              child: ListView.builder(
                itemCount: comparisonList.length,
                itemBuilder: (context, index) {
                  final item = comparisonList[index];
                  return _buildComparisonItem(item);
                },
              ),
            ),

            // Actions
            const Divider(),
            Row(
              children: [
                Text(
                  '${comparisonList.length} products compared',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonItem(Map<String, dynamic> item) {
    final productName = item['product_name'] ?? '';
    final previousQty = item['previous_quantity'] ?? 0;
    final currentQty = item['current_quantity'] ?? 0;
    final difference = item['difference'] ?? 0;
    final unit = item['unit'] ?? '';
    final severity = item['severity'] ?? 'normal';
    final inventoryMatches = item['inventory_matches'] ?? true;

    Color severityColor;
    IconData severityIcon;
    
    switch (severity) {
      case 'high':
        severityColor = Colors.red;
        severityIcon = Icons.warning;
        break;
      case 'medium':
        severityColor = Colors.orange;
        severityIcon = Icons.info;
        break;
      case 'low':
        severityColor = Colors.yellow[700]!;
        severityIcon = Icons.info_outline;
        break;
      default:
        severityColor = Colors.green;
        severityIcon = Icons.check_circle;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Severity indicator
            Icon(severityIcon, color: severityColor, size: 20),
            const SizedBox(width: 12),
            
            // Product info
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (!inventoryMatches)
                    Text(
                      'Inventory mismatch!',
                      style: TextStyle(
                        color: Colors.red[600],
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
            
            // Previous quantity
            Expanded(
              child: Column(
                children: [
                  Text(
                    '$previousQty',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Previous',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            
            // Arrow
            Icon(Icons.arrow_forward, color: Colors.grey[400], size: 16),
            
            // Current quantity
            Expanded(
              child: Column(
                children: [
                  Text(
                    '$currentQty',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Current',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            
            // Difference
            Expanded(
              child: Column(
                children: [
                  Text(
                    difference > 0 ? '+$difference' : '$difference',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: difference > 0 ? Colors.green : difference < 0 ? Colors.red : Colors.grey,
                    ),
                  ),
                  Text(
                    unit,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

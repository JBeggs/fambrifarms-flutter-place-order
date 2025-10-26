import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../../providers/suppliers_provider.dart';
import '../../features/auth/karl_auth_provider.dart';
import '../../models/supplier.dart';
import '../../config/app_config.dart';
import 'widgets/supplier_card.dart';
import 'widgets/supplier_search.dart';
import 'widgets/add_supplier_dialog.dart';
import 'widgets/edit_supplier_dialog.dart';

class SuppliersPage extends ConsumerStatefulWidget {
  const SuppliersPage({super.key});

  @override
  ConsumerState<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends ConsumerState<SuppliersPage> {
  // Selection and editing state
  Set<int> _selectedSupplierIds = <int>{};
  bool _isEditMode = false;
  List<Map<String, dynamic>> _procurementItems = [];

  @override
  void initState() {
    super.initState();
    _loadProcurementItems();
  }

  @override
  Widget build(BuildContext context) {
    final karl = ref.watch(karlAuthProvider).user;
    final suppliersState = ref.watch(suppliersProvider);
    final suppliersList = ref.watch(suppliersListProvider);
    final suppliersStats = ref.watch(suppliersStatsProvider);
    final activeSuppliers = ref.watch(activeSuppliersProvider);

    if (karl == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Very dark background like dashboard
      appBar: AppBar(
        title: const Text('Supplier Management'),
        backgroundColor: const Color(0xFF2D5016), // Dark green AppBar to match dashboard
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/karl-dashboard'),
        ),
        actions: [
          // Edit Mode buttons for Procurement Management
          IconButton(
            onPressed: _toggleEditMode,
            icon: Icon(
              _isEditMode ? Icons.edit_off : Icons.edit,
              color: _isEditMode ? Colors.orange : Colors.white,
            ),
            tooltip: _isEditMode ? 'Exit Edit Mode' : 'Edit Procurement',
          ),
          if (_isEditMode) ...[
            IconButton(
              onPressed: _toggleSelectAll,
              icon: Icon(
                _selectedSupplierIds.length == activeSuppliers.length
                    ? Icons.deselect 
                    : Icons.select_all,
                color: Colors.white,
              ),
              tooltip: _selectedSupplierIds.length == activeSuppliers.length
                  ? 'Deselect All'
                  : 'Select All',
            ),
            if (_selectedSupplierIds.isNotEmpty) ...[
              IconButton(
                onPressed: _showBulkProcurementDialog,
                icon: const Icon(Icons.tune, color: Colors.cyan),
                tooltip: 'Bulk Edit Procurement',
              ),
            ],
          ],
          
          // Performance insights
          if (activeSuppliers.isNotEmpty && !_isEditMode)
            IconButton(
              icon: Badge(
                label: Text('${activeSuppliers.length}'),
                child: const Icon(Icons.analytics),
              ),
              onPressed: () {
                _showPerformanceInsightsDialog(context, activeSuppliers);
              },
            ),
          
          // Refresh button
          if (!_isEditMode)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.read(suppliersProvider.notifier).refresh();
                _loadProcurementItems();
              },
            ),
          
          // Add supplier button
          if (!_isEditMode)
            IconButton(
              icon: const Icon(Icons.add_business),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const AddSupplierDialog(),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Edit Mode Status Banner
          if (_isEditMode) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF2D5016),
              child: Row(
                children: [
                  const Icon(Icons.business_center, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedSupplierIds.isEmpty
                          ? 'Procurement Edit Mode: Select suppliers to manage their products'
                          : 'Selected ${_selectedSupplierIds.length} supplier${_selectedSupplierIds.length == 1 ? '' : 's'} for procurement management',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_selectedSupplierIds.isNotEmpty) ...[
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedSupplierIds.clear();
                        });
                      },
                      child: const Text(
                        'Clear Selection',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          
          // Stats header
          _buildStatsHeader(context, suppliersStats),
          
          // Search and filters
          if (!_isEditMode) const SupplierSearch(),
          
          // Suppliers list
          Expanded(
            child: _buildSuppliersList(context, ref, suppliersState, suppliersList),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(BuildContext context, Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // First row of stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'Total Suppliers',
                  stats['total'].toString(),
                  Icons.business,
                  const Color(0xFF2D5016),
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: _buildStatCard(
                  context,
                  'Active',
                  stats['active'].toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: _buildStatCard(
                  context,
                  'Recent Orders',
                  stats['recent'].toString(),
                  Icons.schedule,
                  Colors.blue,
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: _buildStatCard(
                  context,
                  'Sales Reps',
                  stats['total_sales_reps'].toString(),
                  Icons.people,
                  Colors.purple,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Second row of stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'Total Value',
                  'R${(stats['total_value'] as double).toStringAsFixed(0)}',
                  Icons.attach_money,
                  Colors.orange,
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: _buildStatCard(
                  context,
                  'Avg Order',
                  'R${(stats['average_order_value'] as double).toStringAsFixed(0)}',
                  Icons.trending_up,
                  Colors.teal,
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Placeholder for symmetry
              const Expanded(child: SizedBox()),
              
              const SizedBox(width: 12),
              
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSuppliersList(
    BuildContext context,
    WidgetRef ref,
    SuppliersState state,
    List<dynamic> suppliers,
  ) {
    if (state.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading suppliers...'),
          ],
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading suppliers',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(suppliersProvider.notifier).refresh();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (suppliers.isEmpty) {
      final hasFilters = state.searchQuery.isNotEmpty || 
                        state.selectedType != SupplierType.all;
      
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters ? Icons.search_off : Icons.business_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'No suppliers found' : 'No suppliers yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters 
                  ? 'Try adjusting your search or filters'
                  : 'Suppliers will appear here once they\'re added',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  ref.read(suppliersProvider.notifier).clearAllFilters();
                },
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(suppliersProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: suppliers.length,
        itemBuilder: (context, index) {
          final supplier = suppliers[index];
          final bool isSelected = _selectedSupplierIds.contains(supplier.id);
          
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: _isEditMode && isSelected 
                ? const Color(0xFF2D5016).withOpacity(0.3)
                : null,
            elevation: _isEditMode && isSelected ? 8 : 2,
            child: Column(
              children: [
                if (_isEditMode) ...[
                  // Checkbox header for edit mode
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _selectedSupplierIds.add(supplier.id);
                              } else {
                                _selectedSupplierIds.remove(supplier.id);
                              }
                            });
                          },
                          activeColor: const Color(0xFF2D5016),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${supplier.displayName} - Manage Procurement',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? const Color(0xFF2D5016) : null,
                            ),
                          ),
                        ),
                        if (isSelected) ...[
                          IconButton(
                            onPressed: () => _showSupplierProcurementDetails(supplier),
                            icon: const Icon(Icons.inventory, color: Color(0xFF2D5016)),
                            tooltip: 'View Products',
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isSelected) ...[
                    // Show procurement summary for selected supplier
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: const Color(0xFF2D5016).withOpacity(0.1),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: Color(0xFF2D5016)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getProcurementSummary(supplier),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2D5016),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                
                // Original supplier card (only show when not in edit mode)
                if (!_isEditMode) ...[
                  SupplierCard(
                    supplier: supplier,
                    onTap: () {
                      context.push('/suppliers/${supplier.id}');
                    },
                    onEdit: () {
                      showDialog(
                        context: context,
                        builder: (context) => EditSupplierDialog(supplier: supplier),
                      );
                    },
                    onViewProducts: () {
                      _showSupplierProcurementDetails(supplier);
                    },
                    onContact: () {
                      // TODO: Contact supplier functionality
                      if (supplier.primarySalesRep != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Contact ${supplier.primarySalesRep!.displayName}'),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Contact ${supplier.displayName}'),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPerformanceInsightsDialog(
    BuildContext context, 
    List<dynamic> activeSuppliers,
  ) {
    // Calculate some basic insights
    final suppliersWithMetrics = activeSuppliers
        .where((s) => s.metrics != null)
        .toList();
    
    final avgQuality = suppliersWithMetrics.isNotEmpty
        ? suppliersWithMetrics
            .map((s) => s.metrics!.qualityRating)
            .reduce((a, b) => a + b) / suppliersWithMetrics.length
        : 0.0;
    
    final avgDeliveryRate = suppliersWithMetrics.isNotEmpty
        ? suppliersWithMetrics
            .map((s) => s.metrics!.onTimeDeliveryRate)
            .reduce((a, b) => a + b) / suppliersWithMetrics.length
        : 0.0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.analytics, color: Colors.blue),
            SizedBox(width: 8),
            Text('Performance Insights'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Active Suppliers: ${activeSuppliers.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              if (suppliersWithMetrics.isNotEmpty) ...[
                Text('Average Quality Rating: ${avgQuality.toStringAsFixed(1)}/5.0'),
                const SizedBox(height: 4),
                Text('Average On-Time Delivery: ${(avgDeliveryRate * 100).toStringAsFixed(1)}%'),
                const SizedBox(height: 12),
                
                const Text(
                  'Top Performers:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                
                ...suppliersWithMetrics
                    .where((s) => s.metrics!.qualityRating >= 4.0)
                    .take(3)
                    .map((supplier) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• ${supplier.displayName} (${supplier.metrics!.qualityRatingDisplay})'),
                    )),
              ] else ...[
                const Text('No performance metrics available yet.'),
                const SizedBox(height: 8),
                const Text('Metrics will be calculated as orders are processed.'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navigate to detailed analytics
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Detailed analytics feature coming soon!'),
                ),
              );
            },
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }

  // ===== NEW PROCUREMENT MANAGEMENT METHODS =====

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (!_isEditMode) {
        _selectedSupplierIds.clear();
      }
    });
  }

  void _toggleSelectAll() {
    final suppliers = ref.read(activeSuppliersProvider);
    setState(() {
      if (_selectedSupplierIds.length == suppliers.length) {
        // Deselect all
        _selectedSupplierIds.clear();
      } else {
        // Select all
        _selectedSupplierIds = suppliers.map((supplier) => supplier.id).toSet();
      }
    });
  }

  void _loadProcurementItems() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.djangoBaseUrl}/products/procurement/recommendations/'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> result = json.decode(response.body);
        setState(() {
          _procurementItems = List<Map<String, dynamic>>.from(result['items'] ?? []);
        });
      }
    } catch (e) {
      // Silently fail - procurement items are optional for supplier management
      print('Failed to load procurement items: $e');
    }
  }

  String _getProcurementSummary(dynamic supplier) {
    final supplierItems = _procurementItems
        .where((item) => item['supplier_name'] == supplier.displayName)
        .toList();
    
    if (supplierItems.isEmpty) {
      return 'No current procurement items for this supplier';
    }
    
    final totalItems = supplierItems.length;
    final totalValue = supplierItems
        .map((item) => (item['cost'] as num).toDouble())
        .fold(0.0, (sum, cost) => sum + cost);
    
    return '$totalItems items • R${totalValue.toStringAsFixed(0)} total value';
  }

  void _showSupplierProcurementDetails(dynamic supplier) {
    final supplierItems = _procurementItems
        .where((item) => item['supplier_name'] == supplier.displayName)
        .toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.inventory, color: Color(0xFF2D5016)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${supplier.displayName} Products'),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: supplierItems.isEmpty
              ? const Center(
                  child: Text('No procurement items for this supplier'),
                )
              : ListView.builder(
                  itemCount: supplierItems.length,
                  itemBuilder: (context, index) {
                    final item = supplierItems[index];
                    return ListTile(
                      leading: const Icon(Icons.shopping_cart, size: 16),
                      title: Text(item['product_name'] ?? 'Unknown Product'),
                      subtitle: Text('Qty: ${item['quantity']} • R${item['cost']}'),
                      trailing: Text(
                        item['priority'] ?? 'Normal',
                        style: TextStyle(
                          color: item['priority'] == 'Critical' 
                              ? Colors.red 
                              : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (supplierItems.isNotEmpty) ...[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showSupplierProductEditor(supplier, supplierItems);
              },
              child: const Text('Edit Products'),
            ),
          ],
        ],
      ),
    );
  }

  void _showSupplierProductEditor(dynamic supplier, List<Map<String, dynamic>> items) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${supplier.displayName} Products'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              Text(
                'Manage product assignments and quantities',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        title: Text(item['product_name'] ?? 'Unknown'),
                        subtitle: Text('Current: ${item['quantity']} • R${item['cost']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () {
                                // TODO: Edit quantity
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Quantity editing coming soon!'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit, size: 16),
                            ),
                            IconButton(
                              onPressed: () {
                                // TODO: Change supplier
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Supplier reassignment coming soon!'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.swap_horiz, size: 16),
                            ),
                          ],
                        ),
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Changes saved successfully!'),
                ),
              );
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showBulkProcurementDialog() {
    if (_selectedSupplierIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select suppliers first'),
        ),
      );
      return;
    }

    final selectedSuppliers = ref.read(activeSuppliersProvider)
        .where((supplier) => _selectedSupplierIds.contains(supplier.id))
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Bulk Procurement Management (${_selectedSupplierIds.length} suppliers)',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selected suppliers:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[300],
                ),
              ),
              const SizedBox(height: 8),
              ...selectedSuppliers.map((supplier) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${supplier.displayName}',
                  style: const TextStyle(color: Colors.white70),
                ),
              )),
              const SizedBox(height: 16),
              const Text(
                'Bulk Actions:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
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
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Bulk actions applied to ${_selectedSupplierIds.length} suppliers'),
                ),
              );
              setState(() {
                _selectedSupplierIds.clear();
              });
            },
            child: const Text('Apply Changes'),
          ),
        ],
      ),
    );
  }
}


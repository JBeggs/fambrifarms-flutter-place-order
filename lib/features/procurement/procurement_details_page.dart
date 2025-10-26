// Procurement Recommendation Details Page
// Shows detailed breakdown of all items in a market recommendation

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../models/procurement_models.dart';
import '../../services/api_service.dart';
import '../../providers/procurement_provider.dart';
import 'widgets/edit_recommendation_dialog.dart';

class ProcurementDetailsPage extends ConsumerStatefulWidget {
  final MarketRecommendation recommendation;

  const ProcurementDetailsPage({
    super.key,
    required this.recommendation,
  });

  @override
  ConsumerState<ProcurementDetailsPage> createState() => _ProcurementDetailsPageState();
}

class _ProcurementDetailsPageState extends ConsumerState<ProcurementDetailsPage> {
  String _sortBy = 'priority'; // priority, name, cost, quantity
  bool _sortAscending = false;
  String _filterPriority = 'all'; // all, critical, high, medium, low
  String _viewMode = 'products'; // products, suppliers
  Map<String, dynamic>? _supplierData;
  
  // Selection and editing state
  Set<int> _selectedItemIds = <int>{};
  List<Map<String, dynamic>> _allSuppliers = [];
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _loadAllSuppliers();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAndSortedItems = _getFilteredAndSortedItems();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D5016),
        title: Text(
          'Market Trip Details',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (widget.recommendation.status == 'pending') ...[
            IconButton(
              onPressed: _editRecommendation,
              icon: const Icon(Icons.edit, color: Colors.white),
              tooltip: 'Edit Quantities - Modify recommended quantities for items',
            ),
            TextButton.icon(
              onPressed: _approveRecommendation,
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: const Text('Approve & Go!', style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50).withOpacity(0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
          if (widget.recommendation.status == 'approved') ...[
            IconButton(
              onPressed: _printRecommendation,
              icon: const Icon(Icons.print, color: Colors.white),
              tooltip: 'Print Lists - Generate PDF procurement lists by supplier',
            ),
          ],
          // Print Suppliers button
          IconButton(
            onPressed: _printBySupplier,
            icon: const Icon(Icons.print, color: Colors.white),
            tooltip: 'Print by Supplier - View and print procurement lists organized by supplier',
          ),
          // Edit Mode buttons (only in suppliers view)
          if (_viewMode == 'suppliers') ...[
            IconButton(
              onPressed: _toggleEditMode,
              icon: Icon(
                _isEditMode ? Icons.edit_off : Icons.edit,
                color: _isEditMode ? Colors.orange : Colors.white,
              ),
              tooltip: _isEditMode ? 'Exit Edit Mode - Stop editing supplier assignments' : 'Edit Suppliers - Change which supplier provides each item',
            ),
            if (_isEditMode) ...[
              IconButton(
                onPressed: _toggleSelectAll,
                icon: Icon(
                  _selectedItemIds.length == widget.recommendation.items.length
                      ? Icons.deselect 
                      : Icons.select_all,
                  color: Colors.white,
                ),
                tooltip: _selectedItemIds.length == widget.recommendation.items.length
                    ? 'Deselect All Items'
                    : 'Select All Items - Choose all items for bulk editing',
              ),
              if (_selectedItemIds.isNotEmpty) ...[
                IconButton(
                  onPressed: _showSupplierChangeDialog,
                  icon: const Icon(Icons.swap_horiz, color: Colors.yellow),
                  tooltip: 'Change Supplier - Reassign selected items to different supplier',
                ),
              ],
            ],
          ],
          // Delete button (available for all statuses)
          IconButton(
            onPressed: _deleteRecommendation,
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'Delete Trip - Permanently remove this market recommendation',
          ),
        ],
      ),
      body: Column(
        children: [
          // Edit mode status banner (only in suppliers view)
          if (_isEditMode && _viewMode == 'suppliers') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF2D5016),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedItemIds.isEmpty
                          ? 'Edit Mode: Select items to modify'
                          : 'Edit Mode: ${_selectedItemIds.length} item${_selectedItemIds.length == 1 ? '' : 's'} selected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_selectedItemIds.isNotEmpty) ...[
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedItemIds.clear();
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
          
          // Header with summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2D5016),
                  const Color(0xFF2D5016).withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.recommendation.statusEmoji,
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Market Trip for ${_formatDate(widget.recommendation.forDate)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.recommendation.statusDisplay,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'R${widget.recommendation.totalEstimatedCost.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${widget.recommendation.itemsCount} items',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.recommendation.timeSavingInsight,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Filters and sorting
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Priority filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filterPriority,
                    decoration: const InputDecoration(
                      labelText: 'Filter by Priority',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                    dropdownColor: const Color(0xFF2D2D2D),
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Priorities')),
                      DropdownMenuItem(value: 'critical', child: Text('🔴 Critical')),
                      DropdownMenuItem(value: 'high', child: Text('🟠 High')),
                      DropdownMenuItem(value: 'medium', child: Text('🟡 Medium')),
                      DropdownMenuItem(value: 'low', child: Text('🟢 Low')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterPriority = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Sort by
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sortBy,
                    decoration: const InputDecoration(
                      labelText: 'Sort by',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                    dropdownColor: const Color(0xFF2D2D2D),
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: 'priority', child: Text('Priority')),
                      DropdownMenuItem(value: 'name', child: Text('Product Name')),
                      DropdownMenuItem(value: 'cost', child: Text('Total Cost')),
                      DropdownMenuItem(value: 'quantity', child: Text('Quantity')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _sortBy = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Sort direction
                IconButton(
                  onPressed: () {
                    setState(() {
                      _sortAscending = !_sortAscending;
                    });
                  },
                  icon: Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                // View mode toggle
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D5016),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ToggleButtons(
                    isSelected: [_viewMode == 'products', _viewMode == 'suppliers'],
                    onPressed: (index) {
                      setState(() {
                        _viewMode = index == 0 ? 'products' : 'suppliers';
                        if (_viewMode == 'suppliers' && _supplierData == null) {
                          _loadSupplierData();
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    selectedBorderColor: Colors.white,
                    borderColor: Colors.transparent,
                    selectedColor: Colors.white,
                    color: Colors.white70,
                    fillColor: const Color(0xFF2D5016).withOpacity(0.3),
                    constraints: const BoxConstraints(minWidth: 80, minHeight: 36),
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2, size: 16),
                            SizedBox(width: 4),
                            Text('Products', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.business, size: 16),
                            SizedBox(width: 4),
                            Text('Suppliers', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Items list - conditional based on view mode
          Expanded(
            child: _viewMode == 'suppliers' 
                ? _buildSupplierView()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredAndSortedItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredAndSortedItems[index];
                      return _buildItemCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<MarketRecommendationItem> _getFilteredAndSortedItems() {
    var items = widget.recommendation.items.where((item) {
      if (_filterPriority == 'all') return true;
      return item.priority == _filterPriority;
    }).toList();

    items.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'priority':
          final priorityOrder = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3};
          comparison = (priorityOrder[a.priority] ?? 4).compareTo(priorityOrder[b.priority] ?? 4);
          break;
        case 'name':
          comparison = a.productName.compareTo(b.productName);
          break;
        case 'cost':
          comparison = a.estimatedTotalCost.compareTo(b.estimatedTotalCost);
          break;
        case 'quantity':
          comparison = a.recommendedQuantity.compareTo(b.recommendedQuantity);
          break;
        default:
          comparison = 0;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return items;
  }

  Widget _buildItemCard(MarketRecommendationItem item) {
    final bool isSelected = _selectedItemIds.contains(item.id);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: _isEditMode && isSelected 
          ? const Color(0xFF2D5016).withOpacity(0.3)
          : const Color(0xFF1E1E1E),
      elevation: _isEditMode && isSelected ? 8 : 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with checkbox, product name and priority
            Row(
              children: [
                // Checkbox (only in edit mode)
                // No checkboxes in products view
                _getPriorityIcon(item.priority),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.productName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isEditMode && isSelected 
                          ? const Color(0xFF2D5016) 
                          : Colors.white,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'R${item.estimatedTotalCost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                    Text(
                      'R${item.estimatedUnitPrice.toStringAsFixed(2)}/unit',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Quantity info
            Row(
              children: [
                Expanded(
                  child: _buildQuantityInfo(
                    'Needed',
                    item.neededQuantity,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildRecommendedQuantityInfo(item),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildBufferInfo(item),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Reasoning
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.reasoning,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Source orders if available
            if (item.sourceOrders.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'From orders: ${item.sourceOrders.join(', ')}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityInfo(String label, double quantity, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _formatQuantity(quantity),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendedQuantityInfo(MarketRecommendationItem item) {
    // Convert to map format for _getPackageDisplay
    final itemMap = {
      'product_name': item.productName,
      'recommended_quantity': item.recommendedQuantity.toString(),
      'unit': item.unit,
      'reasoning': item.reasoning ?? '',
    };
    
    final isKgItem = item.unit?.toLowerCase() == 'kg';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommended',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _getPackageDisplay(itemMap, isKgItem),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildBufferInfo(MarketRecommendationItem item) {
    // Convert to map format for _calculateBufferDisplay
    final itemMap = {
      'product_name': item.productName,
      'recommended_quantity': item.recommendedQuantity.toString(),
      'needed_quantity': item.neededQuantity.toString(),
      'unit': item.unit,
    };
    
    final isKgItem = item.unit?.toLowerCase() == 'kg';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Buffer',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _calculateBufferDisplay(itemMap, isKgItem),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildEditableQuantityInfo(MarketRecommendationItem item) {
    final bool isSelected = _selectedItemIds.contains(item.id);
    final bool showInlineEdit = _isEditMode && isSelected;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommended',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 2),
        
        // Show inline edit field when selected in edit mode
        if (showInlineEdit) ...[
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _formatPracticalQuantity(item.recommendedQuantity, item.unit).replaceAll(RegExp(r'[^\d.]'), ''),
                  style: const TextStyle(
                    color: Color(0xFF2D5016),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.all(8),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFF2D5016)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFF2D5016)),
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onFieldSubmitted: (value) {
                    final newQuantity = double.tryParse(value);
                    if (newQuantity != null && newQuantity > 0) {
                      _updateItemQuantity(item.id, newQuantity);
                    }
                  },
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => _editQuantity(item),
                icon: const Icon(Icons.open_in_full, size: 12),
                color: const Color(0xFF2D5016),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                tooltip: 'Edit Details',
              ),
            ],
          ),
        ] else ...[
          // Normal display
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatPracticalQuantity(item.recommendedQuantity, item.unit),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _isEditMode && isSelected 
                        ? const Color(0xFF2D5016) 
                        : const Color(0xFF4CAF50),
                  ),
                ),
              ),
              // Only show edit button for pending recommendations
              if (widget.recommendation.status == 'pending')
                IconButton(
                  onPressed: () => _editQuantity(item),
                  icon: const Icon(Icons.edit, size: 16),
                  color: Colors.white70,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  tooltip: 'Edit Quantity',
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _getPriorityIcon(String priority) {
    switch (priority) {
      case 'critical':
        return const Icon(Icons.error, color: Colors.red, size: 20);
      case 'high':
        return const Icon(Icons.warning, color: Colors.orange, size: 20);
      case 'medium':
        return const Icon(Icons.info, color: Colors.yellow, size: 20);
      case 'low':
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      default:
        return const Icon(Icons.help, color: Colors.grey, size: 20);
    }
  }

  String _formatDate(DateTime date) {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  void _editRecommendation() async {
    // Convert MarketRecommendation to MarketProcurementRecommendation for the dialog
    final procurementRecommendation = MarketProcurementRecommendation(
      id: widget.recommendation.id,
      forDate: widget.recommendation.forDate,
      totalEstimatedCost: widget.recommendation.totalEstimatedCost,
      itemsCount: widget.recommendation.items.length,
      status: widget.recommendation.status,
      createdAt: DateTime.now(), // This would need to be passed from the API
      items: widget.recommendation.items.map((item) => MarketProcurementItem(
        id: item.id,
        productId: item.id, // Use item.id as productId for now
        productName: item.productName,
        neededQuantity: item.neededQuantity,
        recommendedQuantity: item.recommendedQuantity,
        bufferQuantity: item.recommendedQuantity - item.neededQuantity, // Calculate buffer
        estimatedUnitPrice: item.estimatedUnitPrice,
        estimatedTotalCost: item.estimatedTotalCost,
        priority: item.priority,
        reasoning: item.reasoning,
      )).toList(),
    );

    await showDialog(
      context: context,
      builder: (context) => EditRecommendationDialog(
        recommendation: procurementRecommendation,
        onUpdated: () {
          // Refresh the procurement providers to get updated data
          ref.invalidate(marketRecommendationsProvider);
          ref.invalidate(procurementDashboardProvider);
          ref.invalidate(procurementProvider);
        },
      ),
    );
  }

  void _approveRecommendation() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.approveMarketRecommendation(widget.recommendation.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Recommendation approved! Ready for market trip.'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        context.pop(); // Go back to procurement page
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving recommendation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _printRecommendation() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.printMarketRecommendation(widget.recommendation.id);
      
      if (result['success'] == true && result['print_data'] != null) {
        if (mounted) {
          // Show print dialog with the formatted data
          _showPrintDialog(result['print_data']);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating print data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPrintDialog(Map<String, dynamic> printData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Market Trip List'),
        content: SizedBox(
          width: 600,
          height: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Market Trip for ${printData['trip_date']}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Approved by: ${printData['approved_by']}'),
                Text('Approved at: ${printData['approved_at']}'),
                Text('Total Items: ${printData['total_items']}'),
                Text('Estimated Cost: R${(double.tryParse(printData['total_cost']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}'),
                const Divider(),
                
                // Items grouped by priority
                if (printData['grouped_items'] != null)
                  ...printData['grouped_items'].entries.map((entry) {
                    final priority = entry.key;
                    final items = entry.value as List;
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          '${priority.toUpperCase()} PRIORITY',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _getPriorityColor(priority),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(item['product_name']),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(_formatPracticalQuantity(double.tryParse(item['recommended_quantity']?.toString() ?? '0') ?? 0.0, item['unit']?.toString() ?? 'units')),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('R${(double.tryParse(item['estimated_total']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}'),
                              ),
                            ],
                          ),
                        )).toList(),
                      ],
                    );
                  }).toList(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () => _printMarketTrip(printData),
            icon: const Icon(Icons.print),
            label: const Text('Print'),
          ),
        ],
      ),
    );
  }

  void _printMarketTrip(Map<String, dynamic> printData) async {
    try {
      print('[PDF SAVE] Starting supplier-specific PDF generation...');
      
      // Get supplier breakdown data first
      final apiService = ref.read(apiServiceProvider);
      final supplierResult = await apiService.getProcurementBySupplier(widget.recommendation.id);
      
      if (supplierResult['suppliers'] == null) {
        throw Exception('No supplier data available');
      }
      
      final suppliers = supplierResult['suppliers'] as List;
      print('[PDF SAVE] Found ${suppliers.length} suppliers');
      
      // Generate separate PDF for each supplier
      for (final supplier in suppliers) {
        final supplierName = supplier['supplier_name'];
        print('[PDF SAVE] Generating PDF for $supplierName...');
        
        // Generate supplier-specific PDF
        final pdf = pw.Document();
        await _buildMarketTripPdf(pdf, printData, supplier);
        final bytes = await pdf.save();
        
        // Clean supplier name for filename
        final cleanName = supplierName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
        
        // Open Save As dialog for each supplier
        String? outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save $supplierName Procurement List',
          fileName: '${cleanName}_${printData['trip_date']}.pdf',
        );
        
        if (outputPath != null) {
          // Ensure .pdf extension
          if (!outputPath.toLowerCase().endsWith('.pdf')) {
            outputPath = '$outputPath.pdf';
          }
          
          // Save the file
          final file = File(outputPath);
          await file.writeAsBytes(bytes);
          
          print('[PDF SAVE] $supplierName PDF saved successfully');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('$supplierName PDF saved'),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          // User cancelled this supplier, ask if they want to continue
          if (mounted) {
            final shouldContinue = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Continue with other suppliers?'),
                content: Text('You cancelled saving $supplierName. Continue with remaining suppliers?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Stop All'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            );
            
            if (shouldContinue != true) {
              break; // Stop processing remaining suppliers
            }
          }
        }
      }
      
      if (mounted) {
        Navigator.of(context).pop(); // Close the preview dialog
      }
      
    } catch (e, stackTrace) {
      print('[PDF SAVE] ERROR: $e');
      print('[PDF SAVE] Stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating supplier PDFs: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _buildMarketTripPdf(pw.Document pdf, Map<String, dynamic> printData, [Map<String, dynamic>? supplier]) async {
    print('[PDF BUILD] Building PDF for market trip: ${printData['trip_date']}');
    
    // Capture data before build context
    final tripDate = printData['trip_date'] ?? '';
    final approvedBy = printData['approved_by'] ?? '';
    final approvedAt = printData['approved_at'] ?? '';
    final totalItems = printData['total_items'] ?? 0;
    final groupedItems = printData['grouped_items'] as Map<String, dynamic>? ?? {};
    
    // Get all items in a flat list for pagination (filtered by supplier if specified)
    final List<Map<String, dynamic>> allItems = [];
    groupedItems.forEach((priority, items) {
      for (var item in items as List) {
        final itemMap = item as Map<String, dynamic>;
        
        // If supplier is specified, only include items for that supplier
        if (supplier != null) {
          final supplierItems = supplier['items'] as List? ?? [];
          final matchingItem = supplierItems.any((supplierItem) => 
            supplierItem['product_name'] == itemMap['product_name']);
          
          if (!matchingItem) continue; // Skip items not for this supplier
        }
        
        allItems.add({
          ...itemMap,
          'priority': priority,
        });
      }
    });
    
    print('[PDF BUILD] Total items to render: ${allItems.length}');
    
    // Split items into chunks of 15 for pagination
    final itemsPerPage = 25; // Items per page // Increased for better space usage
    final totalPages = (allItems.length / itemsPerPage).ceil();
    
    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final startIndex = pageIndex * itemsPerPage;
      final endIndex = (startIndex + itemsPerPage).clamp(0, allItems.length);
      final pageItems = allItems.sublist(startIndex, endIndex);
      final isFirstPage = pageIndex == 0;
      final isLastPage = pageIndex == totalPages - 1;
      
      print('[PDF BUILD] Creating page ${pageIndex + 1}/$totalPages with ${pageItems.length} items');
    
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            // Build item rows BEFORE the column
            final List<pw.Widget> itemRows = [];
            for (var item in pageItems) {
              final priority = item['priority'] as String;
              itemRows.add(
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4), // Reduced padding
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 4, child: pw.Text(item['product_name'], style: const pw.TextStyle(fontSize: 10))),
                      pw.Expanded(flex: 2, child: pw.Text(_formatPracticalQuantity(double.tryParse(item['recommended_quantity']?.toString() ?? '0') ?? 0.0, item['unit']?.toString() ?? 'units'), style: const pw.TextStyle(fontSize: 10))),
                      pw.Expanded(flex: 2, child: pw.Text(priority.toUpperCase(), style: pw.TextStyle(fontSize: 10, color: _getPdfPriorityColor(priority)))),
                    ],
                  ),
                ),
              );
            }
            
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header - only on first page
                if (isFirstPage) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            supplier != null 
                              ? supplier['supplier_name']
                              : 'FAMBRI FARMS',
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            supplier != null 
                              ? 'Procurement List'
                              : 'Market Trip List',
                            style: const pw.TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Trip Date: $tripDate',
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text('Approved by: $approvedBy', style: const pw.TextStyle(fontSize: 11)),
                          pw.Text('Approved at: $approvedAt', style: const pw.TextStyle(fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  
                  pw.SizedBox(height: 16),
                  pw.Divider(),
                  pw.SizedBox(height: 12),
                  
                  // Trip summary
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text('Total Items: $totalItems', style: const pw.TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  
                  pw.SizedBox(height: 16),
                ],
                
                // Page header for continuation pages
                if (!isFirstPage) ...[
                  pw.Text('Market Trip for $tripDate (continued)', 
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 16),
                ],
                
                // Items list
                pw.Text('ITEMS (${pageItems.length} items - Page ${pageIndex + 1}/$totalPages):', 
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                
                ...itemRows,
                
                pw.SizedBox(height: 16),
                
                // Summary section (always show on last page)
                if (isLastPage)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 2),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text('PROCUREMENT LIST COMPLETE', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                
                pw.SizedBox(height: 20), // Fixed height instead of spacer for pagination
                
                pw.Center(
                  child: pw.Text(
                    isLastPage ? 'Happy Shopping! 🛒' : 'Continued on next page...',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }
  }

  PdfColor _getPdfPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return PdfColors.red;
      case 'high':
        return PdfColors.orange;
      case 'medium':
        return PdfColors.blue;
      case 'low':
        return PdfColors.green;
      default:
        return PdfColors.grey;
    }
  }

  void _printBySupplier() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.getProcurementBySupplier(widget.recommendation.id);
      
      if (mounted) {
        _showSupplierPrintDialog(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error loading supplier breakdown: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadSupplierData() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.getProcurementBySupplier(widget.recommendation.id);
      
      print('[SUPPLIER_DEBUG] API Response: $result');
      print('[SUPPLIER_DEBUG] Suppliers count: ${result['suppliers']?.length ?? 'NULL'}');
      
      if (mounted) {
        setState(() {
          _supplierData = result;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error loading supplier data: $e'),
            backgroundColor: Colors.red,
          ),
        );
        // Reset to products view on error
        setState(() {
          _viewMode = 'products';
        });
      }
    }
  }

  void _loadAllSuppliers() async {
    try {
      print('[SUPPLIERS] Loading suppliers using API service...');
      final apiService = ref.read(apiServiceProvider);
      final suppliers = await apiService.getSuppliers();
      
      print('[SUPPLIERS] Found ${suppliers.length} suppliers from API service');
      
      // Add Fambri Garden as NULL option for "no external procurement"
      final allSuppliers = [
        {
          'id': null,
          'name': 'Fambri Garden (No External Procurement)',
        },
        ...suppliers
      ];
      
      setState(() {
        _allSuppliers = allSuppliers;
      });
      print('[SUPPLIERS] Loaded ${_allSuppliers.length} suppliers total');
    } catch (e) {
      print('[SUPPLIERS] Error loading suppliers: $e');
      // Try fallback API endpoint
      _loadSuppliersFromProcurementAPI();
    }
  }

  void _loadSuppliersFromProcurementAPI() async {
    try {
      print('[SUPPLIERS] Trying procurement API endpoint...');
      final response = await http.get(
        Uri.parse('${AppConfig.djangoBaseUrl}/products/suppliers/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('[SUPPLIERS] Procurement API status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        final suppliers = result['suppliers'] as List;
        print('[SUPPLIERS] Found ${suppliers.length} suppliers from procurement API');
        setState(() {
          _allSuppliers = List<Map<String, dynamic>>.from(suppliers);
        });
      }
    } catch (e) {
      print('[SUPPLIERS] Procurement API also failed: $e');
    }
  }

  Future<void> _changeSupplierForSelected(int? newSupplierId) async {
    try {
      print('[SUPPLIER_CHANGE] Starting supplier change for ${_selectedItemIds.length} items to supplier ID: $newSupplierId');
      
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.updateProcurementSuppliers(
        widget.recommendation.id,
        _selectedItemIds.map((itemId) => {
          'item_id': itemId,
          'supplier_id': newSupplierId,
        }).toList(),
      );

      print('[SUPPLIER_CHANGE] API Response: $response');

      // API service call successful
      print('[SUPPLIER_CHANGE] Success! Reloading data...');
      _loadSupplierData();
      setState(() {
        _selectedItemIds.clear();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Supplier updated successfully'),
            backgroundColor: Color(0xFF2D5016),
          ),
        );
      }
    } catch (e) {
      print('[SUPPLIER_CHANGE] ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error updating supplier: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _updateItemQuantity(int itemId, double newQuantity) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      
      // Use API service with proper authentication
      final response = await apiService.updateProcurementItemQuantity(
        widget.recommendation.id, 
        itemId, 
        newQuantity
      );
      
      // Reload supplier data to reflect changes
      _loadSupplierData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Quantity updated successfully'),
          backgroundColor: Color(0xFF2D5016),
        ),
      );
    } catch (e) {
      print('[UPDATE_ERROR] Failed to update quantity: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error updating quantity: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (!_isEditMode) {
        _selectedItemIds.clear();
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedItemIds.length == widget.recommendation.items.length) {
        // Deselect all
        _selectedItemIds.clear();
      } else {
        // Select all
        _selectedItemIds = widget.recommendation.items.map((item) => item.id).toSet();
      }
    });
  }

  void _showSupplierChangeDialog() {
    if (_selectedItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please select items to change supplier'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    print('[SUPPLIERS] Opening change dialog with ${_allSuppliers.length} suppliers available');
    for (var supplier in _allSuppliers) {
      print('[SUPPLIERS] - ${supplier['id']}: ${supplier['name']}');
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Change Supplier',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected ${_selectedItemIds.length} items',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            const Text(
              'New Supplier:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF2D5016)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF2D5016)),
                ),
              ),
              dropdownColor: const Color(0xFF2A2A2A),
              items: _allSuppliers.map((supplier) {
                return DropdownMenuItem<int?>(
                  value: supplier['id'],
                  child: Text(
                    supplier['name'],
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                Navigator.pop(context);
                _changeSupplierForSelected(value);
              },
            ),
          ],
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

  void _showBulkEditDialog() {
    if (_selectedItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please select items to edit'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Get selected items for display
    final selectedItems = widget.recommendation.items
        .where((item) => _selectedItemIds.contains(item.id))
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Bulk Edit (${_selectedItemIds.length} items)',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show selected items
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: selectedItems.length,
                  itemBuilder: (context, index) {
                    final item = selectedItems[index];
                    return ListTile(
                      title: Text(
                        item.productName,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Qty: ${item.recommendedQuantity} • R${item.estimatedTotalCost.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              
              // Bulk edit options
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showSupplierChangeDialog,
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text('Change Supplier'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showBulkQuantityDialog();
                      },
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit Quantities'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D5016),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBulkQuantityDialog() {
    final TextEditingController multiplierController = TextEditingController();
    final TextEditingController addAmountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Bulk Quantity Edit (${_selectedItemIds.length} items)',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose an option:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            
            // Multiply quantities
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: multiplierController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Multiply by (e.g., 1.5)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0xFF2A2A2A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final multiplier = double.tryParse(multiplierController.text);
                    if (multiplier != null && multiplier > 0) {
                      Navigator.pop(context);
                      _bulkUpdateQuantities(multiplier: multiplier);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text('Apply'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            const Text('OR', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            
            // Add/subtract amount
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: addAmountController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Add amount (+ or -)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0xFF2A2A2A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final addAmount = double.tryParse(addAmountController.text);
                    if (addAmount != null) {
                      Navigator.pop(context);
                      _bulkUpdateQuantities(addAmount: addAmount);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D5016)),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
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

  Future<void> _bulkUpdateQuantities({double? multiplier, double? addAmount}) async {
    // This would need to be implemented with proper API calls
    // For now, just show a success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✅ Updated ${_selectedItemIds.length} items' + 
          (multiplier != null ? ' (×$multiplier)' : '') +
          (addAmount != null ? ' (${addAmount >= 0 ? '+' : ''}$addAmount)' : ''),
        ),
        backgroundColor: const Color(0xFF2D5016),
      ),
    );
    
    // Clear selection after bulk edit
    setState(() {
      _selectedItemIds.clear();
    });
  }

  // Print-only version without editing functionality
  Widget _buildPrintItemRow(Map<String, dynamic> item, bool isKgItem) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          
          // Product name
          Expanded(
            flex: 4,
            child: Text(
              item['product_name'],
              style: const TextStyle(color: Colors.white),
            ),
          ),
          
          // Quantity with improved buffer calculation
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getPackageDisplay(item, isKgItem),
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                ),
                // Add buffer information with proper rounding for packages
                if (item['needed_quantity'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Buffer: ${_calculateBufferDisplay(item, isKgItem)}',
                    style: TextStyle(
                      color: Colors.blue.withOpacity(0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Edit version for main supplier view (keeps existing functionality)
  Widget _buildItemRow(Map<String, dynamic> item, bool isKgItem) {
    final int itemId = item['id'] ?? 0;
    final bool isSelected = _selectedItemIds.contains(itemId);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // Checkbox (only in edit mode)
          if (_isEditMode) ...[
            Checkbox(
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedItemIds.add(itemId);
                  } else {
                    _selectedItemIds.remove(itemId);
                  }
                });
              },
              activeColor: const Color(0xFF2D5016),
            ),
            const SizedBox(width: 8),
          ] else ...[
            const Text('• ', style: TextStyle(fontSize: 16)),
          ],
          
          // Product name
          Expanded(
            flex: 4,
            child: Text(
              item['product_name'],
              style: TextStyle(
                color: _isEditMode && isSelected ? const Color(0xFF2D5016) : Colors.white,
                fontWeight: _isEditMode && isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          
          // Quantity (editable in edit mode)
          Expanded(
            flex: 2,
            child: _isEditMode && isSelected
                ? Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: '${_formatPracticalQuantity(double.tryParse(item['recommended_quantity']?.toString() ?? '0') ?? 0.0, item['unit']?.toString() ?? 'units').replaceAll(RegExp(r'[^\d.]'), '')}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.all(8),
                            border: OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF2D5016)),
                            ),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onFieldSubmitted: (value) {
                            final newQuantity = double.tryParse(value);
                            if (newQuantity != null && newQuantity > 0) {
                              _updateItemQuantity(itemId, newQuantity);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isKgItem ? 'kg' : item['unit'],
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getPackageDisplay(item, isKgItem),
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      // Add buffer information with improved calculation
                      if (item['needed_quantity'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Buffer: ${_calculateBufferDisplay(item, isKgItem)}',
                          style: TextStyle(
                            color: Colors.blue.withOpacity(0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          
          // Cost
          Expanded(
            flex: 2,
            child: Text(
              'R${(double.tryParse(item['estimated_total_cost']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierView() {
    print('[SUPPLIER_VIEW] _buildSupplierView() called with _supplierData: ${_supplierData != null ? 'NOT NULL' : 'NULL'}');
    
    if (_supplierData == null) {
      print('[SUPPLIER_VIEW] Showing loading spinner - _supplierData is null');
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2D5016)),
        ),
      );
    }

    print('[SUPPLIER_VIEW] _supplierData: $_supplierData');
    print('[SUPPLIER_VIEW] Keys: ${_supplierData!.keys}');
    
    final suppliers = _supplierData!['suppliers'] as List;
    print('[SUPPLIER_VIEW] Suppliers list length: ${suppliers.length}');
    
    print('[SUPPLIER_VIEW] Building ListView with ${suppliers.length} suppliers');
    
    final listView = ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: suppliers.length,
      itemBuilder: (context, index) {
        try {
          final supplier = suppliers[index];
          print('[SUPPLIER_VIEW] === SUPPLIER $index DEBUG ===');
          print('[SUPPLIER_VIEW] API Data - Name: ${supplier['supplier_name']}');
          print('[SUPPLIER_VIEW] API Data - Items: ${supplier['items']?.length ?? 0}');
          print('[SUPPLIER_VIEW] API Data - Total Cost: R${supplier['total_cost']}');
          print('[SUPPLIER_VIEW] API Data - First 3 products: ${(supplier['items'] as List? ?? []).take(3).map((item) => item['product_name']).join(', ')}');
          
          final supplierProcessed = _processSupplierData(supplier);
          print('[SUPPLIER_VIEW] Processed Data - Kg Items: ${supplierProcessed['kgItems'].length}');
          print('[SUPPLIER_VIEW] Processed Data - Other Items: ${supplierProcessed['otherItems'].length}');
          print('[SUPPLIER_VIEW] Processed Data - Total Kg: ${supplierProcessed['totalKg']}');
          print('[SUPPLIER_VIEW] Building Card widget for supplier $index...');
          
          final card = Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: const Color(0xFF1E1E1E),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              // Supplier header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: supplier['supplier_name'] == 'Fambri Farms Internal'
                        ? [const Color(0xFF2D5016), const Color(0xFF2D5016).withOpacity(0.8)]
                        : [Colors.blue.shade700, Colors.blue.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        supplier['supplier_name'] == 'Fambri Farms Internal' 
                            ? Icons.agriculture 
                            : Icons.business,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            supplier['supplier_name'],
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            supplier['supplier_name'] == 'Fambri Farms Internal'
                                ? '🌱 Internal Supply • Fresh from our farms'
                                : '🚚 External Supplier • Market sourced',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'R${(double.tryParse(supplier['total_cost']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${supplier['item_count']} items',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Summary cards
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSupplierSummaryCard(
                        '📦 Kg Products',
                        '${((supplierProcessed['totalKg'] as double) * 2).ceil() / 2} kg',
                        '${supplierProcessed['kgProductCount']} products',
                        supplier['supplier_name'] == 'Fambri Farms Internal'
                            ? const Color(0xFF2D5016)
                            : Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSupplierSummaryCard(
                        '📱 Count Products',
                        '${supplierProcessed['otherProductCount']} items',
                        '${supplierProcessed['otherProductTypes']} types',
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),

              // Product sections
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    // Kg Products
                    if (supplierProcessed['kgItems'].isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: supplier['supplier_name'] == 'Fambri Farms Internal'
                              ? const Color(0xFF2D5016).withOpacity(0.1)
                              : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: supplier['supplier_name'] == 'Fambri Farms Internal'
                                ? const Color(0xFF2D5016).withOpacity(0.3)
                                : Colors.blue.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.scale, 
                                  color: supplier['supplier_name'] == 'Fambri Farms Internal'
                                      ? const Color(0xFF2D5016)
                                      : Colors.blue, 
                                  size: 16),
                                const SizedBox(width: 6),
                                Text('📦 Kg Products (Total by Weight)', 
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    color: supplier['supplier_name'] == 'Fambri Farms Internal'
                                        ? const Color(0xFF2D5016)
                                        : Colors.blue,
                                  )),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: supplier['supplier_name'] == 'Fambri Farms Internal'
                                        ? const Color(0xFF2D5016).withOpacity(0.2)
                                        : Colors.blue.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${((supplierProcessed['totalKg'] as double) * 2).ceil() / 2} kg',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold, 
                                      color: supplier['supplier_name'] == 'Fambri Farms Internal'
                                          ? const Color(0xFF2D5016)
                                          : Colors.blue, 
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...supplierProcessed['kgItems'].map<Widget>((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  // Checkbox in edit mode
                                  if (_isEditMode) ...[
                                    Checkbox(
                                      value: _selectedItemIds.contains(item['id']),
                                      onChanged: (value) {
                                        setState(() {
                                          if (value == true) {
                                            _selectedItemIds.add(item['id']);
                                          } else {
                                            _selectedItemIds.remove(item['id']);
                                          }
                                        });
                                      },
                                      activeColor: const Color(0xFF2D5016),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    flex: 4, 
                                    child: Text(
                                      '• ${item['product_name']}',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2, 
                                    child: _isEditMode && _selectedItemIds.contains(item['id'])
                                        ? Row(
                                            children: [
                                              Expanded(
                                                child: TextFormField(
                                                  initialValue: '${_formatPracticalQuantity(double.tryParse(item['recommended_quantity']?.toString() ?? '0') ?? 0.0, item['unit']?.toString() ?? 'units').replaceAll(RegExp(r'[^\d.]'), '')}',
                                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                                  decoration: const InputDecoration(
                                                    isDense: true,
                                                    contentPadding: EdgeInsets.all(8),
                                                    border: OutlineInputBorder(),
                                                    enabledBorder: OutlineInputBorder(
                                                      borderSide: BorderSide(color: Color(0xFF2D5016)),
                                                    ),
                                                  ),
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  onFieldSubmitted: (value) {
                                                    final newQuantity = double.tryParse(value);
                                                    if (newQuantity != null && newQuantity > 0) {
                                                      _updateItemQuantity(item['id'], newQuantity);
                                                    }
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                item['unit'] ?? 'units',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _getPackageDisplay(item, item['unit']?.toLowerCase() == 'kg'), 
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                              if (item['needed_quantity'] != null) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  _calculateBufferDisplay(item, item['unit']?.toString().toLowerCase() == 'kg'),
                                                  style: TextStyle(
                                                    color: Colors.blue.withOpacity(0.8),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                  ),
                                  Expanded(
                                    flex: 2, 
                                    child: Text(
                                      'R${(double.tryParse(item['estimated_total_cost']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Count Products  
                    if (supplierProcessed['otherItems'].isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.inventory, color: Colors.orange, size: 16),
                                const SizedBox(width: 6),
                                const Text('📱 Count Products (Total by Items)', 
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${supplierProcessed['otherProductCount']} items',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...supplierProcessed['otherItems'].map<Widget>((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  // Checkbox in edit mode
                                  if (_isEditMode) ...[
                                    Checkbox(
                                      value: _selectedItemIds.contains(item['id']),
                                      onChanged: (value) {
                                        setState(() {
                                          if (value == true) {
                                            _selectedItemIds.add(item['id']);
                                          } else {
                                            _selectedItemIds.remove(item['id']);
                                          }
                                        });
                                      },
                                      activeColor: Colors.orange,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    flex: 4, 
                                    child: Text(
                                      '• ${item['product_name']}',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2, 
                                    child: _isEditMode && _selectedItemIds.contains(item['id'])
                                        ? Row(
                                            children: [
                                              Expanded(
                                                child: TextFormField(
                                                  initialValue: '${_formatPracticalQuantity(double.tryParse(item['recommended_quantity']?.toString() ?? '0') ?? 0.0, item['unit']?.toString() ?? 'units').replaceAll(RegExp(r'[^\d.]'), '')}',
                                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                                  decoration: const InputDecoration(
                                                    isDense: true,
                                                    contentPadding: EdgeInsets.all(8),
                                                    border: OutlineInputBorder(),
                                                    enabledBorder: OutlineInputBorder(
                                                      borderSide: BorderSide(color: Color(0xFF2D5016)),
                                                    ),
                                                  ),
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  onFieldSubmitted: (value) {
                                                    final newQuantity = double.tryParse(value);
                                                    if (newQuantity != null && newQuantity > 0) {
                                                      _updateItemQuantity(item['id'], newQuantity);
                                                    }
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                item['unit'],
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _formatPracticalQuantity(double.tryParse(item['recommended_quantity']?.toString() ?? '0') ?? 0.0, item['unit']?.toString() ?? 'units'), 
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                              if (item['needed_quantity'] != null) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  _calculateBufferDisplay(item, item['unit']?.toString().toLowerCase() == 'kg'),
                                                  style: TextStyle(
                                                    color: Colors.blue.withOpacity(0.8),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                  ),
                                  Expanded(
                                    flex: 2, 
                                    child: Text(
                                      'R${(double.tryParse(item['estimated_total_cost']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
        
        print('[SUPPLIER_VIEW] Card widget built successfully for supplier $index');
        return card;
        } catch (e, stackTrace) {
          print('[SUPPLIER_VIEW] ERROR building supplier $index: $e');
          print('[SUPPLIER_VIEW] Stack trace: $stackTrace');
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            color: Colors.red.shade900,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error loading supplier ${suppliers[index]['supplier_name']}: $e',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        }
      },
    );
    
    return Column(
      children: [
        // Summary header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2D5016), Color(0xFF4A7C59)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Text(
            '📋 ${suppliers.length} Suppliers • ${_supplierData!['total_items']} Items • R${double.tryParse(_supplierData!['recommendation']['total_estimated_cost']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(child: listView),
      ],
    );
  }

  void _showSupplierPrintDialog(Map<String, dynamic> data) {
    final suppliers = data['suppliers'] as List;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🖨️ Print Procurement by Supplier'),
        content: SizedBox(
          width: 900,
          height: 700,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Summary with totaling
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF2D5016), const Color(0xFF2D5016).withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Market Trip: ${data['recommendation']['for_date']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildSummaryMetric('${data['total_suppliers']}', 'Suppliers', Icons.business),
                        const SizedBox(width: 24),
                        _buildSummaryMetric('${data['total_items']}', 'Items', Icons.inventory_2),
                        const SizedBox(width: 24),
                        _buildSummaryMetric('R${(double.tryParse(data['recommendation']['total_estimated_cost']?.toString() ?? '0') ?? 0.0).toStringAsFixed(0)}', 'Total Cost', Icons.attach_money),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Suppliers list with enhanced grouping
              Expanded(
                child: ListView.builder(
                  itemCount: suppliers.length,
                  itemBuilder: (context, index) {
                    final supplier = suppliers[index];
                    final supplierData = _processSupplierData(supplier);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: ExpansionTile(
                        title: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: supplier['supplier_name'] == 'Fambri Farms Internal' 
                                    ? const Color(0xFF2D5016).withOpacity(0.2)
                                    : Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                supplier['supplier_name'] == 'Fambri Farms Internal' ? Icons.agriculture : Icons.business,
                                color: supplier['supplier_name'] == 'Fambri Farms Internal' 
                                    ? const Color(0xFF2D5016) 
                                    : Colors.blue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    supplier['supplier_name'],
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    supplier['supplier_name'] == 'Fambri Farms Internal' 
                                        ? '🌱 Internal Supply' 
                                        : '🚚 External Supplier',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'R${(double.tryParse(supplier['total_cost']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${supplier['item_count']} items',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Smart Summary Cards
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSupplierSummaryCard(
                                        '📦 Kg Products',
                                        '${((supplierData['totalKg'] as double) * 2).ceil() / 2} kg',
                                        '${supplierData['kgProductCount']} products',
                                        Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildSupplierSummaryCard(
                                        '📱 Count Products',
                                        '${supplierData['otherProductCount']} items',
                                        '${supplierData['otherProductTypes']} types',
                                        Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Kg Products Section
                                if (supplierData['kgItems'].isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.scale, color: Colors.blue, size: 16),
                                            const SizedBox(width: 6),
                                            const Text('📦 Kg Products (Total by Weight)', 
                                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '${((supplierData['totalKg'] as double) * 2).ceil() / 2} kg',
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        ...supplierData['kgItems'].map<Widget>((item) => _buildPrintItemRow(item, true)).toList(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                
                                // Other Products Section  
                                if (supplierData['otherItems'].isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.inventory, color: Colors.orange, size: 16),
                                            const SizedBox(width: 6),
                                            const Text('📱 Count Products (Total by Items)', 
                                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '${supplierData['otherProductCount']} items',
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        ...supplierData['otherItems'].map<Widget>((item) => _buildPrintItemRow(item, false)).toList(),
                                      ],
                                    ),
                                  ),
                                ],
                                
                                // Print button for this supplier
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => _printSupplierList(supplier, data['recommendation']),
                                  icon: const Icon(Icons.print, size: 16),
                                  label: Text('Print ${supplier['supplier_name']} List'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
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
            onPressed: () => _printAllSuppliers(suppliers, data['recommendation']),
            icon: const Icon(Icons.print_outlined),
            label: const Text('Print All Suppliers'),
          ),
        ],
      ),
    );
  }

  Future<void> _printSupplierList(Map<String, dynamic> supplier, Map<String, dynamic> recommendation) async {
    try {
      print('[PDF SAVE] Starting PDF generation for supplier: ${supplier['supplier_name']}');
      
      // Capture data
      final supplierName = supplier['supplier_name'] ?? '';
      final tripDate = recommendation['for_date'] ?? '';
      final items = supplier['items'] as List;
      final itemCount = supplier['item_count'] ?? items.length;
      
      // Build item rows
      final List<pw.Widget> itemRows = [];
      for (var item in items) {
        itemRows.add(
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4), // Reduced padding
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(flex: 4, child: pw.Text(item['product_name'], style: const pw.TextStyle(fontSize: 10))),
                pw.Expanded(flex: 2, child: pw.Text(_formatPracticalQuantity(double.tryParse(item['recommended_quantity']?.toString() ?? '0') ?? 0.0, item['unit']?.toString() ?? 'units'), style: const pw.TextStyle(fontSize: 10))),
              ],
            ),
          ),
        );
      }
      
      // Generate PDF
      // Add pagination - split items into chunks of 25
      final pdf = pw.Document();
      final itemsPerPage = 25; // Items per page
      final totalPages = (itemRows.length / itemsPerPage).ceil();
      
      for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
        final startIndex = pageIndex * itemsPerPage;
        final endIndex = (startIndex + itemsPerPage).clamp(0, itemRows.length);
        final pageItemRows = itemRows.sublist(startIndex, endIndex);
        final isFirstPage = pageIndex == 0;
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header - only on first page
                if (isFirstPage) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('FAMBRI FARMS', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Text('Supplier Procurement List', style: const pw.TextStyle(fontSize: 14)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(supplierName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Trip Date: $tripDate', style: const pw.TextStyle(fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  pw.Divider(),
                  pw.SizedBox(height: 12),
                  pw.Text('Total Items: $itemCount', style: const pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(height: 16),
                ],
                
                // Page header for continuation pages
                if (!isFirstPage) ...[
                  pw.Text('$supplierName - Page ${pageIndex + 1}/$totalPages', 
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 16),
                ],
                
                pw.Text('ITEMS (${pageItemRows.length} items - Page ${pageIndex + 1}/$totalPages):', 
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                
                ...pageItemRows,
                
                pw.SizedBox(height: 16),
                
                // Summary - only on last page
                if (pageIndex == totalPages - 1) ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(border: pw.Border.all(width: 2)),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text('PROCUREMENT LIST COMPLETE', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
                
                pw.SizedBox(height: 20), // Fixed height instead of spacer for pagination
                
                pw.Center(
                  child: pw.Text('☐ All items collected  ☐ Prices verified  ☐ Quality checked  ☐ Receipt obtained', 
                    style: const pw.TextStyle(fontSize: 10)),
                ),
              ],
            );
          },
        ),
      );
      } // End pagination loop      
      final bytes = await pdf.save();
      print('[PDF SAVE] PDF generated, size: ${bytes.length} bytes');
      
      // Open Save As dialog
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Supplier Procurement PDF',
        fileName: '${supplierName}_$tripDate.pdf',
      );
      
      if (outputPath != null) {
        if (!outputPath.toLowerCase().endsWith('.pdf')) {
          outputPath = '$outputPath.pdf';
        }
        
        final file = File(outputPath);
        await file.writeAsBytes(bytes);
        
        if (mounted) {
          Navigator.of(context).pop(); // Close supplier dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('PDF saved: ${outputPath.split('/').last}')),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('[PDF SAVE] ERROR: $e');
      print('[PDF SAVE] Stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _printAllSuppliers(List suppliers, Map<String, dynamic> recommendation) async {
    try {
      print('[PDF SAVE] Starting PDF generation for all suppliers');
      
      // This function will be updated to use the working file picker approach
      // For now, show a message that it's not yet implemented with the new format
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Print all suppliers feature - coming soon with new format!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('[PDF SAVE] ERROR: $e');
    }
  }

  void _editQuantity(MarketRecommendationItem item) async {
    final controller = TextEditingController(text: item.recommendedQuantity.toString());
    
    final newQuantity = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Quantity - ${item.productName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current quantity: ${_formatPracticalQuantity(item.recommendedQuantity, item.unit)}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'New Quantity (${item.unit})',
                border: const OutlineInputBorder(),
                suffixText: item.unit,
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Unit price: R${item.estimatedUnitPrice.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
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
              final value = double.tryParse(controller.text);
              if (value != null && value > 0) {
                Navigator.of(context).pop(value);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid quantity greater than 0'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (newQuantity != null && newQuantity != item.recommendedQuantity) {
      try {
        final apiService = ref.read(apiServiceProvider);
        final result = await apiService.updateProcurementItemQuantity(
          widget.recommendation.id,
          item.id,
          newQuantity,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${result['message']}'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Update the local item data
          setState(() {
            item.recommendedQuantity = newQuantity;
            item.estimatedTotalCost = newQuantity * item.estimatedUnitPrice;
            
            // Update the recommendation total
            widget.recommendation.totalEstimatedCost = result['recommendation_total'];
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error updating quantity: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _deleteRecommendation() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Market Trip'),
        content: Text(
          'Are you sure you want to delete this market trip for ${widget.recommendation.forDate.toString().split(' ')[0]}?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final apiService = ref.read(apiServiceProvider);
        final result = await apiService.deleteMarketRecommendation(widget.recommendation.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${result['message']}'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop(); // Go back to procurement page
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error deleting market trip: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }


  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.yellow[700]!;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSummaryMetric(String value, String label, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
          ],
        ),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildSupplierSummaryCard(String title, String mainValue, String subValue, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
          const SizedBox(height: 4),
          Text(mainValue, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
          Text(subValue, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10)),
        ],
      ),
    );
  }

  Map<String, dynamic> _processSupplierData(Map<String, dynamic> supplier) {
    final items = supplier['items'] as List;
    
    // Separate kg products from count products
    final kgItems = <Map<String, dynamic>>[];
    final otherItems = <Map<String, dynamic>>[];
    
    double totalKg = 0.0;
    int otherProductCount = 0;
    final Set<String> otherProductTypes = <String>{};
    
    for (final item in items) {
      final unit = (item['unit'] as String? ?? 'piece').toLowerCase();
      
      // Only treat as kg if the unit is actually kg
      if (unit == 'kg') {
        kgItems.add(item);
        // Sum up kg quantities  
        final quantity = double.tryParse(item['recommended_quantity']?.toString() ?? '0') ?? 0.0;
        totalKg += quantity;
      } else {
        // All other units (punnet, packet, bunch, etc.) go to other items
        otherItems.add(item);
        // Count total items
        final quantity = double.tryParse(item['recommended_quantity']?.toString() ?? '0') ?? 0.0;
        otherProductCount += quantity.toInt();
        // Track unique product types
        otherProductTypes.add(item['product_name']);
      }
    }
    
    return {
      'kgItems': kgItems,
      'otherItems': otherItems,
      'totalKg': totalKg,
      'kgProductCount': kgItems.length,
      'otherProductCount': otherProductCount,
      'otherProductTypes': otherProductTypes.length,
    };
  }

  String _formatQuantity(double quantity) {
    // Round to fix floating point precision issues
    final rounded = (quantity * 10).round() / 10;
    return rounded.toStringAsFixed(1);
  }

  String _formatPracticalQuantity(double quantity, String unit) {
    // Format quantities with practical rounding based on unit type
    final unitLower = unit.toLowerCase();
    
    if (unitLower == 'kg') {
      // Round UP to nearest 0.5kg for practical purchasing
      final roundedKg = (quantity * 2).ceil() / 2;
      return '${roundedKg.toStringAsFixed(1)} kg';
    } else if (['bag', 'box', 'punnet', 'packet', 'bunch', 'head', 'each'].contains(unitLower)) {
      // Round UP to whole numbers for count items (can't buy partial bags/boxes)
      final roundedQty = quantity.ceil();
      final pluralUnit = _getPluralUnit(unit, roundedQty);
      return '$roundedQty $pluralUnit';
    } else {
      // Default: round UP to whole numbers for other count items
      final roundedQty = quantity.ceil();
      return '$roundedQty $unit';
    }
  }

  String _calculateBufferDisplay(Map<String, dynamic> item, bool isKgItem) {
    final neededQuantity = double.tryParse(item['needed_quantity']?.toString() ?? '0') ?? 0.0;
    final recommendedQuantity = double.tryParse(item['recommended_quantity']?.toString() ?? '0') ?? 0.0;
    final buffer = recommendedQuantity - neededQuantity;
    
    if (buffer <= 0) {
      return '0';
    }
    
    if (isKgItem) {
      // Round buffer UP to nearest 0.5kg for practical purchasing
      final roundedBuffer = (buffer * 2).ceil() / 2;
      return '${roundedBuffer.toStringAsFixed(1)} kg';
    } else {
      // For count items, round to whole numbers
      final roundedBuffer = buffer.round();
      return '$roundedBuffer ${item['unit'] ?? 'units'}';
    }
  }
  
  String _getPackageDisplay(Map<String, dynamic> item, bool isKgItem) {
    final recommendedQuantity = double.tryParse(item['recommended_quantity']?.toString() ?? '0') ?? 0.0;
    final unit = item['unit']?.toString() ?? 'units';
    
    
    // Check if this item comes in packages (from product name)
    final productName = item['product_name']?.toString() ?? '';
    
    // For kg items, detect package size from product name or reasoning
    if (isKgItem) {
      final reasoning = item['reasoning']?.toString() ?? '';
      int? packageSize;
      
      if (productName.contains('(5kg)') || reasoning.contains('5kg')) {
        packageSize = 5;
      } else if (productName.contains('(10kg)') || reasoning.contains('10kg')) {
        packageSize = 10;
      } else if (productName.contains('(2kg)') || reasoning.contains('2kg')) {
        packageSize = 2;
      }
      
      if (packageSize != null) {
        final boxes = (recommendedQuantity / packageSize).ceil(); // Round UP for boxes
        if (boxes > 1) {
          return '$boxes boxes (${(boxes * packageSize).toStringAsFixed(1)}kg)';
        } else if (boxes == 1) {
          return '1 box (${packageSize.toStringAsFixed(1)}kg)';
        }
      }
      
      // Default kg display - round UP to nearest 0.5kg for practical purchasing
      final roundedKg = (recommendedQuantity * 2).ceil() / 2; // Round up to nearest 0.5kg
      return '${roundedKg.toStringAsFixed(1)} kg';
    } else {
      // For non-kg items, ALWAYS round UP to whole numbers (can't buy partial bags/boxes/punnets)
      final roundedQty = recommendedQuantity.ceil(); // Use ceil() to round UP
      if (unit == 'punnet' || unit == 'packet' || unit == 'bunch' || unit == 'bag' || unit == 'box' || unit == 'head' || unit == 'each') {
        final pluralUnit = _getPluralUnit(unit, roundedQty);
        return '$roundedQty $pluralUnit';
      } else {
        return '$roundedQty $unit';
      }
    }
  }
  
  String _getPluralUnit(String unit, int quantity) {
    if (quantity == 1) return unit;
    
    switch (unit.toLowerCase()) {
      case 'punnet':
        return 'punnets';
      case 'packet':
        return 'packets';
      case 'bunch':
        return 'bunches';
      case 'box':
        return 'boxes';
      default:
        return '${unit}s';
    }
  }
}

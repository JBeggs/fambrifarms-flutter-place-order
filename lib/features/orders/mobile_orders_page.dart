import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../models/order.dart';
import '../../models/customer.dart';
import '../../models/product.dart' as product_model;
import '../../providers/orders_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/products_provider.dart';
import '../../services/pdf_service.dart';
import '../../services/excel_service.dart';
import 'widgets/mobile_order_card.dart';
import 'widgets/reserved_stock_view.dart';

class MobileOrdersPage extends ConsumerStatefulWidget {
  const MobileOrdersPage({super.key});

  @override
  ConsumerState<MobileOrdersPage> createState() => _MobileOrdersPageState();
}

class _MobileOrdersPageState extends ConsumerState<MobileOrdersPage>
    with SingleTickerProviderStateMixin {
  String _selectedStatusFilter = 'all';
  String _searchQuery = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Load data when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ordersProvider.notifier).loadOrders();
      ref.read(inventoryProvider.notifier).loadStockLevels();
      ref.read(productsProvider.notifier).loadProducts();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Order> get filteredOrders {
    var orders = ref.watch(ordersProvider).orders;
    
    // Filter by status
    if (_selectedStatusFilter != 'all') {
      orders = orders.where((order) => order.status == _selectedStatusFilter).toList();
    }
    
    // Filter by search query (include business name)
    if (_searchQuery.isNotEmpty) {
      orders = orders.where((order) {
        final query = _searchQuery.toLowerCase();
        final businessName = order.restaurant.profile?.businessName?.toLowerCase() ?? '';
        return order.orderNumber.toLowerCase().contains(query) ||
               order.restaurant.displayName.toLowerCase().contains(query) ||
               businessName.contains(query);
      }).toList();
    }
    
    return orders;
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(ordersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Orders Management',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(
              icon: Icon(Icons.list_alt),
              text: 'Orders List',
            ),
            Tab(
              icon: Icon(Icons.inventory_2),
              text: 'Reserved Stock',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart),
            onPressed: _generateWorkbook,
            tooltip: 'Generate Workbook for Received Orders',
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            onPressed: _markAllConfirmedAsDelivered,
            tooltip: 'Mark All Confirmed as Delivered',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(ordersProvider.notifier).refreshOrders();
              ref.read(inventoryProvider.notifier).loadStockLevels();
            },
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Orders List Tab
          _buildOrdersList(),
          // Reserved Stock Tab
          const ReservedStockView(),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    final ordersState = ref.watch(ordersProvider);
    
    return Column(
      children: [
        // Search and Filters
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Search Bar
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search orders, restaurants, or business names...',
                  prefixIcon: const Icon(Icons.search),
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
              
              const SizedBox(height: 16),
              
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', 'all', _selectedStatusFilter, (value) {
                      setState(() {
                        _selectedStatusFilter = value;
                      });
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('Received', 'received', _selectedStatusFilter, (value) {
                      setState(() {
                        _selectedStatusFilter = value;
                      });
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('Confirmed', 'confirmed', _selectedStatusFilter, (value) {
                      setState(() {
                        _selectedStatusFilter = value;
                      });
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('PO Sent', 'po_sent', _selectedStatusFilter, (value) {
                      setState(() {
                        _selectedStatusFilter = value;
                      });
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('Delivered', 'delivered', _selectedStatusFilter, (value) {
                      setState(() {
                        _selectedStatusFilter = value;
                      });
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('Cancelled', 'cancelled', _selectedStatusFilter, (value) {
                      setState(() {
                        _selectedStatusFilter = value;
                      });
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Orders List
        Expanded(
          child: ordersState.isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading orders...'),
                    ],
                  ),
                )
              : ordersState.error != null
                  ? Center(
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
                            'Error loading orders',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            ordersState.error!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => ref.read(ordersProvider.notifier).refreshOrders(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : filteredOrders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No orders found',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try adjusting your search or filters',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = filteredOrders[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: MobileOrderCard(
                                order: order,
                                onTap: () => _showOrderDetails(context, order),
                                onStatusChanged: (newStatus) {
                                  ref.read(ordersProvider.notifier).updateOrderStatus(order.id, newStatus);
                                },
                              ),
                            );
                          },
                        ),
        ),
        
        // Summary Footer
        if (filteredOrders.isNotEmpty)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredOrders.length} orders',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                _buildQuickStats(),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _markAllConfirmedAsDelivered() async {
    final ordersNotifier = ref.read(ordersProvider.notifier);
    final confirmedOrders = ref.read(ordersProvider).orders
        .where((order) => order.status == 'confirmed')
        .toList();
    
    if (confirmedOrders.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ℹ️ No confirmed orders to mark as delivered'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      return;
    }
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Orders as Delivered?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mark ${confirmedOrders.length} confirmed orders as delivered?'),
            const SizedBox(height: 16),
            const Text(
              'This will:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('✓ Free up reserved stock'),
            const Text('✓ Allow new orders'),
            const Text('✓ Update to "delivered"'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    
    if (confirmed != true || !mounted) return;
    
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Text('Marking ${confirmedOrders.length} orders...'),
          ],
        ),
        duration: const Duration(seconds: 30),
      ),
    );
    
    // Mark each order as delivered
    int successCount = 0;
    int failCount = 0;
    String? lastError;
    
    for (final order in confirmedOrders) {
      try {
        print('[MOBILE_ORDERS] Attempting to mark order ${order.id} (${order.orderNumber}) as delivered');
        await ordersNotifier.updateOrderStatus(order.id, 'delivered');
        print('[MOBILE_ORDERS] Successfully marked order ${order.orderNumber} as delivered');
        successCount++;
      } catch (e, stackTrace) {
        lastError = e.toString();
        print('[MOBILE_ORDERS] Failed to mark order ${order.orderNumber} as delivered: $e');
        print('[MOBILE_ORDERS] Stack trace: $stackTrace');
        failCount++;
      }
    }
    
    // Refresh orders list
    await ordersNotifier.refreshOrders();
    await ref.read(inventoryProvider.notifier).loadStockLevels();
    
    // Show result
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // Check if all failed due to permissions (403 error)
      final isPermissionError = failCount > 0 && 
                                 lastError != null && 
                                 lastError.contains('403');
      
      if (isPermissionError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🔒 Permission Denied',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your account doesn\'t have permission to mark orders as delivered.',
                ),
                const SizedBox(height: 4),
                const Text(
                  'Please contact an administrator.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failCount == 0
                  ? '✅ $successCount orders marked as delivered!'
                  : '⚠️ $successCount done, $failCount failed',
            ),
            backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Generate workbook with all received orders
  Future<void> _generateWorkbook() async {
    try {
      print('[MOBILE WORKBOOK] Starting workbook generation');
      
      final ordersState = ref.read(ordersProvider);
      final allOrders = ordersState.orders;
      
      // Filter for received orders only
      final receivedOrders = allOrders.where((order) => order.status == 'received').toList();
      
      if (receivedOrders.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ No received orders to export'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      print('[MOBILE WORKBOOK] Found ${receivedOrders.length} received orders');
      
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text('Generating workbook for ${receivedOrders.length} orders...'),
              ],
            ),
            duration: const Duration(seconds: 60),
          ),
        );
      }
      
      // Generate filename with current date
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final filename = 'ReceivedOrders_${dateStr}_$timeStr.xlsx';
      
      // Get temporary directory for mobile
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$filename';
      print('[MOBILE WORKBOOK] Saving to: $filePath');
      
      // Create Excel workbook
      final workbook = excel.Excel.createExcel();
      
      // Create a sheet for each order
      for (final order in receivedOrders) {
        // Use business name from profile, fallback to restaurant name
        String businessName = order.restaurant.profile?.businessName ?? order.restaurant.name;
        
        // Use business name as sheet name (sanitize for Excel)
        String sheetName = businessName
            .replaceAll(RegExp(r'[^\w\s-]'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        
        // Excel sheet names must be max 31 chars and unique
        if (sheetName.length > 31) {
          sheetName = sheetName.substring(0, 31);
        }
        
        // Make sure sheet name is unique
        int counter = 1;
        String uniqueSheetName = sheetName;
        while (workbook.sheets.containsKey(uniqueSheetName)) {
          final suffix = '_$counter';
          final maxLength = 31 - suffix.length;
          uniqueSheetName = '${sheetName.substring(0, maxLength < sheetName.length ? maxLength : sheetName.length)}$suffix';
          counter++;
        }
        
        print('[MOBILE WORKBOOK] Creating sheet: $uniqueSheetName for order ${order.orderNumber}');
        
        final sheet = workbook[uniqueSheetName];
        
        // Add professional header with business name
        sheet.cell(excel.CellIndex.indexByString('A1')).value = excel.TextCellValue(businessName.toUpperCase());
        sheet.cell(excel.CellIndex.indexByString('A1')).cellStyle = excel.CellStyle(
          bold: true,
          fontSize: 18,
        );
        
        // Contact information row
        int currentRow = 2;
        List<String> contactParts = [];
        if (order.restaurant.email.isNotEmpty) {
          contactParts.add('Email: ${order.restaurant.email}');
        }
        if (order.restaurant.phone.isNotEmpty) {
          contactParts.add('Tel: ${order.restaurant.phone}');
        }
        if (contactParts.isNotEmpty) {
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue(contactParts.join(' | '));
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = excel.CellStyle(
            fontSize: 10,
          );
          currentRow++;
        }
        
        // Address information
        if (order.restaurant.profile?.deliveryAddress?.isNotEmpty == true) {
          final addressParts = [order.restaurant.profile!.deliveryAddress!];
          if (order.restaurant.profile?.city?.isNotEmpty == true) {
            addressParts.add(order.restaurant.profile!.city!);
          }
          if (order.restaurant.profile?.postalCode?.isNotEmpty == true) {
            addressParts.add(order.restaurant.profile!.postalCode!);
          }
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue(addressParts.join(', '));
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = excel.CellStyle(
            fontSize: 10,
          );
          currentRow++;
        }
        
        currentRow++; // Add space
        
        // Order details section
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue('ORDER DETAILS');
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = excel.CellStyle(
          bold: true,
          fontSize: 14,
        );
        currentRow += 2;
        
        // Order information
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue('Order Number:');
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = excel.CellStyle(bold: true);
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = excel.TextCellValue(order.orderNumber);
        currentRow++;
        
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue('Order Date:');
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = excel.CellStyle(bold: true);
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = excel.TextCellValue(order.orderDate);
        currentRow++;
        
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue('Delivery Date:');
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = excel.CellStyle(bold: true);
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = excel.TextCellValue(order.deliveryDate);
        currentRow++;
        
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue('Status:');
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = excel.CellStyle(bold: true);
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = excel.TextCellValue(order.status.toUpperCase());
        currentRow += 2;
        
        // Order items table
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue('ORDER ITEMS');
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = excel.CellStyle(
          bold: true,
          fontSize: 14,
        );
        currentRow += 2;
        
        // Table headers
        final headers = ['Product', 'Quantity', 'Unit', 'Stock Status', 'Notes'];
        for (int i = 0; i < headers.length; i++) {
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = excel.TextCellValue(headers[i]);
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).cellStyle = excel.CellStyle(
            bold: true,
            horizontalAlign: excel.HorizontalAlign.Center,
          );
        }
        currentRow++;
        
        // Add order items (sorted alphabetically)
        final sortedItems = [...order.items];
        sortedItems.sort((a, b) => a.product.name.toLowerCase().compareTo(b.product.name.toLowerCase()));
        
        for (final item in sortedItems) {
          // Product name with notes
          String productName = item.product.name;
          if (item.notes?.isNotEmpty == true) {
            productName += ' (${item.notes})';
          }
          
          // Stock status
          String stockStatus = 'Unknown';
          if (item.isStockReserved) {
            stockStatus = 'Reserved';
          } else if (item.isNoReserve) {
            stockStatus = 'No Reserve';
          } else if (item.isStockReservationFailed) {
            stockStatus = 'Reservation Failed';
          }
          
          final rowData = [
            excel.TextCellValue(productName),
            excel.DoubleCellValue(item.quantity),
            excel.TextCellValue(item.product.unit),
            excel.TextCellValue(stockStatus),
            excel.TextCellValue(item.notes ?? ''),
          ];
          
          for (int i = 0; i < rowData.length; i++) {
            sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = rowData[i];
          }
          currentRow++;
        }
        
        // Auto-fit columns
        for (int i = 0; i < headers.length; i++) {
          sheet.setColumnAutoFit(i);
        }
      }
      
      // Get products data for additional sheets
      final productsState = ref.read(productsProvider);
      final products = productsState.products;
      
      // Add Reserved Stock sheet
      _addReservedStockSheet(workbook, receivedOrders, products);
      
      // Add Stock to be Ordered sheet
      _addStockToOrderSheet(workbook, receivedOrders, products);
      
      // Remove default Sheet1 AFTER creating all custom sheets
      if (workbook.sheets.containsKey('Sheet1')) {
        workbook.delete('Sheet1');
        print('[MOBILE WORKBOOK] Removed default Sheet1');
      }
      
      // Save Excel file
      print('[MOBILE WORKBOOK] Generating Excel bytes...');
      final excelBytes = workbook.save();
      
      if (excelBytes != null) {
        print('[MOBILE WORKBOOK] Excel bytes generated: ${excelBytes.length} bytes');
        
        // Write to file
        final file = File(filePath);
        await file.writeAsBytes(excelBytes);
        print('[MOBILE WORKBOOK] File written successfully to: $filePath');
        
        // Hide loading snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
        
        // Share the file
        await Share.shareXFiles(
          [XFile(filePath)],
          subject: 'Received Orders - $dateStr',
          text: 'Excel workbook with ${receivedOrders.length} received orders',
        );
        
        print('[MOBILE WORKBOOK] File shared successfully');
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Generated workbook for ${receivedOrders.length} orders'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception('Failed to generate Excel bytes');
      }
    } catch (e, stackTrace) {
      print('[MOBILE WORKBOOK] Error generating workbook: $e');
      print('[MOBILE WORKBOOK] Stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error generating workbook: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Add Reserved Stock sheet to workbook
  void _addReservedStockSheet(excel.Excel workbook, List<Order> orders, List<product_model.Product> products) {
    print('[MOBILE WORKBOOK] Creating Reserved Stock sheet');
    
    final sheet = workbook['Reserved Stock'];
    
    // Sheet title
    sheet.cell(excel.CellIndex.indexByString('A1')).value = excel.TextCellValue('RESERVED STOCK - ALL ORDERS');
    sheet.cell(excel.CellIndex.indexByString('A1')).cellStyle = excel.CellStyle(
      bold: true,
      fontSize: 16,
    );
    
    int currentRow = 3;
    sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue('Summary of all reserved stock across all received orders');
    currentRow += 2;
    
    // Table headers
    final headers = ['Order #', 'Business Name', 'Product', 'Ordered Qty', 'Unit', 'Reserved Qty', 'Stock Level', 'Status'];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = excel.TextCellValue(headers[i]);
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).cellStyle = excel.CellStyle(
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Center,
      );
    }
    currentRow++;
    
    // Collect all reserved stock items from all orders
    // Include both directly reserved items AND source products that are reserved
    List<Map<String, dynamic>> reservedItems = [];
    final addedProductIds = <int>{};
    
    for (final order in orders) {
      // Add directly reserved items
      for (final item in order.items.where((item) => item.isStockReserved)) {
        reservedItems.add({
          'order': order,
          'item': item,
          'isSource': false,
        });
        addedProductIds.add(item.product.id);
      }
      
      // Add source products that are reserved
      for (final item in order.items.where((item) => 
        item.sourceProductId != null && 
        item.sourceProductName != null && 
        item.sourceQuantity != null
      )) {
        // Skip if we already added this source product
        if (!addedProductIds.contains(item.sourceProductId)) {
          reservedItems.add({
            'order': order,
            'item': item,
            'isSource': true,
          });
          addedProductIds.add(item.sourceProductId!);
        }
      }
    }
    
    // Sort by product name
    reservedItems.sort((a, b) {
      final aName = a['isSource'] == true 
        ? '${a['item'].sourceProductName} (Source)'
        : a['item'].product.name;
      final bName = b['isSource'] == true 
        ? '${b['item'].sourceProductName} (Source)'
        : b['item'].product.name;
      return aName.compareTo(bName);
    });
    
    // Add reserved stock items to sheet
    bool hasReservedItems = reservedItems.isNotEmpty;
    for (final reservedData in reservedItems) {
      final order = reservedData['order'] as Order;
      final item = reservedData['item'] as OrderItem;
      final isSource = reservedData['isSource'] as bool;
      
      if (isSource) {
        // Handle source product
        final sourceProduct = products.firstWhere(
          (p) => p.id == item.sourceProductId,
          orElse: () => product_model.Product(
            id: item.sourceProductId!,
            name: item.sourceProductName ?? 'Unknown',
            department: 'Other',
            price: 0,
            unit: item.sourceProductUnit ?? 'kg',
            stockLevel: item.sourceProductStockLevel?.toDouble() ?? 0,
            minimumStock: 0,
          ),
        );
        
        final rowData = [
          excel.TextCellValue(order.orderNumber),
          excel.TextCellValue(order.restaurant.profile?.businessName ?? order.restaurant.name),
          excel.TextCellValue('${item.sourceProductName} (Source)'),
          excel.DoubleCellValue(item.sourceQuantity ?? 0),
          excel.TextCellValue(item.sourceProductUnit ?? 'kg'),
          excel.DoubleCellValue(item.sourceQuantity ?? 0), // Reserved quantity from source
          excel.DoubleCellValue(sourceProduct.stockLevel),
          excel.TextCellValue('✅ Reserved (for ${item.product.name})'),
        ];
        
        for (int i = 0; i < rowData.length; i++) {
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = rowData[i];
        }
        currentRow++;
      } else {
        // Handle directly reserved item
        final product = products.firstWhere(
          (p) => p.id == item.product.id,
          orElse: () => product_model.Product(
            id: item.product.id,
            name: item.product.name,
            department: 'Other',
            price: item.product.price,
            unit: item.product.unit,
            stockLevel: 0,
            minimumStock: 0,
          ),
        );
        
        final rowData = [
          excel.TextCellValue(order.orderNumber),
          excel.TextCellValue(order.restaurant.profile?.businessName ?? order.restaurant.name),
          excel.TextCellValue(item.product.name),
          excel.DoubleCellValue(item.quantity),
          excel.TextCellValue(item.product.unit),
          excel.DoubleCellValue(item.quantity), // Assuming full quantity is reserved
          excel.DoubleCellValue(product.stockLevel),
          excel.TextCellValue('✅ Reserved'),
        ];
        
        for (int i = 0; i < rowData.length; i++) {
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = rowData[i];
        }
        currentRow++;
      }
    }
    
    // If no reserved items, show message
    if (!hasReservedItems) {
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue('No items have reserved stock across all orders');
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = excel.CellStyle(
        italic: true,
      );
    }
    
    // Auto-fit columns
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnAutoFit(i);
    }
    
    print('[MOBILE WORKBOOK] Reserved Stock sheet created successfully');
  }

  /// Add Stock to be Ordered sheet to workbook
  void _addStockToOrderSheet(excel.Excel workbook, List<Order> orders, List<product_model.Product> products) {
    print('[MOBILE WORKBOOK] Creating Stock to be Ordered sheet');
    
    final sheet = workbook['Stock to Order'];
    
    // Sheet title
    sheet.cell(excel.CellIndex.indexByString('A1')).value = excel.TextCellValue('STOCK TO BE ORDERED');
    sheet.cell(excel.CellIndex.indexByString('A1')).cellStyle = excel.CellStyle(
      bold: true,
      fontSize: 16,
    );
    
    int currentRow = 3;
    sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue('Items that need to be ordered (no stock reservation or failed reservation)');
    currentRow += 2;
    
    // Table headers
    final headers = ['Order #', 'Business Name', 'Product', 'Quantity', 'Unit', 'Status', 'Notes'];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = excel.TextCellValue(headers[i]);
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).cellStyle = excel.CellStyle(
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Center,
      );
    }
    currentRow++;
    
    // Collect all items that need to be ordered (no reserve or failed reservation)
    // Exclude unlimited stock products (they're always available)
    List<Map<String, dynamic>> itemsToOrder = [];
    
    print('[MOBILE WORKBOOK] Processing ${orders.length} orders for Stock to Order sheet');
    int totalItems = 0;
    int noReserveCount = 0;
    int failedReserveCount = 0;
    int unlimitedStockCount = 0;
    
    for (final order in orders) {
      print('[MOBILE WORKBOOK] Order ${order.orderNumber}: ${order.items.length} items');
      for (final item in order.items) {
        totalItems++;
        print('[MOBILE WORKBOOK]   - ${item.product.name}: stockAction=${item.stockAction}, isNoReserve=${item.isNoReserve}, isFailed=${item.isStockReservationFailed}');
        
        // Only include items that need ordering (failed reservation or no reserve)
        if (!item.isNoReserve && !item.isStockReservationFailed) {
          continue;
        }
        
        if (item.isNoReserve) noReserveCount++;
        if (item.isStockReservationFailed) failedReserveCount++;
        
        // Find corresponding product to check if it's unlimited stock
        final product = products.firstWhere(
          (p) => p.id == item.product.id,
          orElse: () => product_model.Product(
            id: item.product.id,
            name: item.product.name,
            department: 'Other',
            price: item.product.price,
            unit: item.product.unit,
            stockLevel: 0,
            minimumStock: 0,
          ),
        );
        
        // Skip unlimited stock products (they're always available, no need to order)
        if (product.unlimitedStock) {
          print('[MOBILE WORKBOOK]     -> Skipping ${item.product.name} (unlimited stock)');
          unlimitedStockCount++;
          continue;
        }
        
        print('[MOBILE WORKBOOK]     -> Adding ${item.product.name} to Stock to Order sheet');
        itemsToOrder.add({
          'order': order,
          'item': item,
        });
      }
    }
    
    print('[MOBILE WORKBOOK] Stock to Order summary: Total items=$totalItems, NoReserve=$noReserveCount, Failed=$failedReserveCount, UnlimitedStock=$unlimitedStockCount, ToOrder=${itemsToOrder.length}');
    
    // Sort by product name
    itemsToOrder.sort((a, b) => a['item'].product.name.compareTo(b['item'].product.name));
    
    // Add items to sheet
    bool hasItemsToOrder = itemsToOrder.isNotEmpty;
    for (final orderData in itemsToOrder) {
      final order = orderData['order'] as Order;
      final item = orderData['item'] as OrderItem;
      
      String status = item.isNoReserve ? '⚠️ No Reserve' : '❌ Failed';
      
      final rowData = [
        excel.TextCellValue(order.orderNumber),
        excel.TextCellValue(order.restaurant.profile?.businessName ?? order.restaurant.name),
        excel.TextCellValue(item.product.name),
        excel.DoubleCellValue(item.quantity),
        excel.TextCellValue(item.product.unit),
        excel.TextCellValue(status),
        excel.TextCellValue(item.notes ?? ''),
      ];
      
      for (int i = 0; i < rowData.length; i++) {
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = rowData[i];
      }
      currentRow++;
    }
    
    // If no items to order, show message
    if (!hasItemsToOrder) {
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue('All items have reserved stock');
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = excel.CellStyle(
        italic: true,
      );
    }
    
    // Auto-fit columns
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnAutoFit(i);
    }
    
    print('[MOBILE WORKBOOK] Stock to Order sheet created successfully');
  }

  Widget _buildFilterChip(String label, String value, String currentValue, Function(String) onSelected) {
    final isSelected = currentValue == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.blue,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        onSelected(selected ? value : 'all');
      },
      backgroundColor: Colors.white,
      selectedColor: Colors.blue,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? Colors.blue : Colors.blue.withOpacity(0.5),
      ),
    );
  }

  Widget _buildQuickStats() {
    final pendingCount = filteredOrders.where((order) => 
      order.status == 'received' || order.status == 'parsed').length;
    
    final deliveredCount = filteredOrders.where((order) => 
      order.status == 'delivered').length;

    return Row(
      children: [
        _buildStatBadge(
          icon: Icons.pending,
          count: pendingCount,
          color: Colors.orange,
          label: 'Pending',
        ),
        const SizedBox(width: 12),
        _buildStatBadge(
          icon: Icons.check_circle,
          count: deliveredCount,
          color: Colors.green,
          label: 'Delivered',
        ),
      ],
    );
  }

  Widget _buildStatBadge({
    required IconData icon,
    required int count,
    required Color color,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(BuildContext context, Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
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
                
                // Order details content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    child: _buildOrderDetailsContent(order),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderDetailsContent(Order order) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.orderNumber,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _getCustomerDisplayName(order.restaurant),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(order.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                order.status.toUpperCase(),
                style: TextStyle(
                  color: _getStatusColor(order.status),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Order Items
        const Text(
          'Order Items',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // Sort items alphabetically by product name
        ...(() {
          final sortedItems = [...order.items];
          sortedItems.sort((a, b) => a.product.name.toLowerCase().compareTo(b.product.name.toLowerCase()));
          return sortedItems;
        })().asMap().entries.map((entry) {
          final item = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Quantity: ${item.quantity} ${item.product.unit}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      // Show source product info if available
                      if (item.sourceProductName != null && item.sourceQuantity != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amber.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inventory_2, size: 12, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                'Stock from: ${item.sourceProductName} (${item.sourceQuantity}${item.sourceProductUnit ?? ''})',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.amber[900],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (item.stockAction != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              item.stockAction == 'reserve' ? Icons.lock : Icons.info_outline,
                              size: 14,
                              color: item.stockAction == 'reserve' ? Colors.orange : Colors.blue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.stockAction == 'reserve' ? 'Stock Reserved' : 'No Reservation',
                              style: TextStyle(
                                fontSize: 12,
                                color: item.stockAction == 'reserve' ? Colors.orange : Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (order.status != 'delivered' && order.status != 'cancelled')
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _editOrderItem(order, item),
                        icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                        tooltip: 'Edit item',
                      ),
                      IconButton(
                        onPressed: () => _deleteOrderItem(order, item),
                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                        tooltip: 'Delete item',
                      ),
                    ],
                  ),
              ],
            ),
          );
        }),
        
        // Add Item Button (only if order not delivered/cancelled)
        if (order.status != 'delivered' && order.status != 'cancelled') ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _addItemToOrder(order),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Item'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: Colors.green,
                side: const BorderSide(color: Colors.green, width: 2),
              ),
            ),
          ),
        ],
        
        const SizedBox(height: 24),
        
        // Actions
        // Share Order Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _shareOrder(order),
            icon: const Icon(Icons.share, size: 20),
            label: const Text('Share Order'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: Colors.blue, width: 2),
              foregroundColor: Colors.blue,
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Update Status Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: order.status != 'delivered' ? () async {
              // Update order status based on current status
              String nextStatus;
              switch (order.status) {
                case 'received':
                  nextStatus = 'confirmed';
                  break;
                case 'confirmed':
                  nextStatus = 'po_sent';
                  break;
                case 'po_sent':
                  nextStatus = 'po_confirmed';
                  break;
                case 'po_confirmed':
                  nextStatus = 'delivered';
                  break;
                default:
                  nextStatus = 'delivered';
              }
              
              try {
                print('[DEBUG] MobileOrdersPage: Attempting to update order ${order.id} status to $nextStatus');
                await ref.read(ordersProvider.notifier).updateOrderStatus(order.id, nextStatus);
                
                // Check if there was an error after the update
                final ordersState = ref.read(ordersProvider);
                if (ordersState.error != null) {
                  print('[ERROR] MobileOrdersPage: Order update failed with error: ${ordersState.error}');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Failed to update order: ${ordersState.error}'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                  return; // Don't close the dialog if there was an error
                }
                
                print('[DEBUG] MobileOrdersPage: Order status updated successfully');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Order status updated to ${_getStatusDisplayName(nextStatus)}'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  Navigator.pop(context);
                }
              } catch (e) {
                print('[ERROR] MobileOrdersPage: Exception during order update: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Error updating order: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              }
            } : null,
            icon: const Icon(Icons.arrow_forward),
            label: Text(_getNextStatusLabel(order.status)),
            style: ElevatedButton.styleFrom(
              backgroundColor: order.status != 'delivered' ? Colors.blue : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        
        // Delete Order Button (only if not delivered/cancelled)
        if (order.status != 'delivered' && order.status != 'cancelled') ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _deleteOrder(order),
              icon: const Icon(Icons.delete, size: 20),
              label: const Text('Delete Order'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _deleteOrder(Order order) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            const Expanded(child: Text('Delete Order?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete order ${order.orderNumber}?',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Text(
              'Customer: ${_getCustomerDisplayName(order.restaurant)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            Text(
              'Items: ${order.items.length}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reserved stock will be released. This action cannot be undone.',
                      style: TextStyle(fontSize: 12, color: Colors.red[800]),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            child: const Text('Delete Order'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        // Delete order via API
        await ref.read(ordersProvider.notifier).deleteOrder(order.id);

        if (mounted) {
          // Close loading dialog
          Navigator.of(context).pop();
          
          // Close order details modal
          Navigator.of(context).pop();

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Order ${order.orderNumber} deleted successfully'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

          // Refresh orders and inventory
          await ref.read(ordersProvider.notifier).refreshOrders();
          await ref.read(inventoryProvider.notifier).loadStockLevels();
        }
      } catch (e) {
        if (mounted) {
          // Close loading dialog
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Failed to delete order: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _editOrderItem(Order order, OrderItem item) async {
    // Get products list
    final productsState = ref.read(productsProvider);
    final products = productsState.products;

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No products available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show edit dialog
    await showDialog(
      context: context,
      builder: (context) => _EditItemDialog(
        orderId: order.id,
        orderItem: item,
        products: products,
        onItemUpdated: () {
          // Refresh orders and inventory
          ref.read(ordersProvider.notifier).refreshOrders();
          ref.read(inventoryProvider.notifier).loadStockLevels();
        },
      ),
    );
  }

  Future<void> _shareOrder(Order order) async {
    try {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('Generating files to share...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      String? pdfPath;
      String? excelPath;

      // Generate PDF
      try {
        pdfPath = await PdfService.generateOrderPdf(order);
        print('[ORDER SHARE] PDF generated: $pdfPath');
      } catch (e) {
        print('[ORDER SHARE] Error generating PDF: $e');
      }

      // Generate Excel with products data for additional sheets
      try {
        final productsState = ref.read(productsProvider);
        final products = productsState.products;
        excelPath = await ExcelService.generateOrderExcel(order, products: products);
        print('[ORDER SHARE] Excel generated: $excelPath');
      } catch (e) {
        print('[ORDER SHARE] Error generating Excel: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      // Share files
      if (pdfPath != null || excelPath != null) {
        final List<XFile> filesToShare = [];
        if (pdfPath != null) {
          filesToShare.add(XFile(pdfPath));
        }
        if (excelPath != null) {
          filesToShare.add(XFile(excelPath));
        }

        if (filesToShare.isNotEmpty) {
          await Share.shareXFiles(
            filesToShare,
            subject: 'Order ${order.orderNumber} - ${order.restaurant.displayName}',
            text: 'Order details for ${order.orderNumber}',
          );
          print('[ORDER SHARE] Files shared successfully');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to generate files to share'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('[ORDER SHARE] Error sharing order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error sharing order: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _deleteOrderItem(Order order, OrderItem item) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this item?'),
            const SizedBox(height: 12),
            Text(
              item.product.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Quantity: ${item.quantity} ${item.product.unit}'),
            if (item.stockAction == 'reserve') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reserved stock will be released',
                        style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
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

    if (confirmed == true && mounted) {
      try {
        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        // Delete item via API
        await ref.read(ordersProvider.notifier).deleteOrderItem(order.id, item.id);

        if (mounted) {
          // Close loading
          Navigator.of(context).pop();
          
          // Close order details
          Navigator.of(context).pop();

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Item deleted successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Refresh orders
          await ref.read(ordersProvider.notifier).refreshOrders();
          await ref.read(inventoryProvider.notifier).loadStockLevels();
        }
      } catch (e) {
        if (mounted) {
          // Close loading
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Failed to delete item: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _addItemToOrder(Order order) async {
    // Get products list
    final productsState = ref.read(productsProvider);
    final products = productsState.products;

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No products available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show add item dialog
    await showDialog(
      context: context,
      builder: (context) => _AddItemDialog(
        orderId: order.id,
        products: products,
        onItemAdded: () async {
          // Refresh orders and inventory
          await ref.read(ordersProvider.notifier).refreshOrders();
          await ref.read(inventoryProvider.notifier).loadStockLevels();
        },
      ),
    );
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'received':
        return 'Received';
      case 'confirmed':
        return 'Confirmed';
      case 'po_sent':
        return 'PO Sent';
      case 'po_confirmed':
        return 'PO Confirmed';
      case 'delivered':
        return 'Delivered';
      default:
        return status.replaceAll('_', ' ').split(' ').map((word) => 
          word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : word
        ).join(' ');
    }
  }

  String _getNextStatusLabel(String currentStatus) {
    switch (currentStatus) {
      case 'received':
        return 'Confirm Order';
      case 'confirmed':
        return 'Send PO';
      case 'po_sent':
        return 'Confirm PO';
      case 'po_confirmed':
        return 'Mark Delivered';
      case 'delivered':
        return 'Already Delivered';
      default:
        return 'Update Status';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'received':
        return Colors.blue;
      case 'parsed':
        return Colors.indigo;
      case 'confirmed':
        return Colors.orange;
      case 'po_sent':
        return Colors.purple;
      case 'po_confirmed':
        return Colors.teal;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Get appropriate customer display name based on customer type
  String _getCustomerDisplayName(Customer customer) {
    // For restaurants: use business name if available
    if (customer.isRestaurant) {
      return customer.profile?.businessName ?? customer.name;
    }
    
    // For private customers: use first name only
    if (customer.isPrivate && customer.firstName.isNotEmpty) {
      return customer.firstName;
    }
    
    // Fallback to default display name
    return customer.displayName;
  }
}

// Add Item Dialog
class _AddItemDialog extends ConsumerStatefulWidget {
  final int orderId;
  final List<product_model.Product> products;
  final VoidCallback onItemAdded;

  const _AddItemDialog({
    required this.orderId,
    required this.products,
    required this.onItemAdded,
  });

  @override
  ConsumerState<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends ConsumerState<_AddItemDialog> {
  product_model.Product? _selectedProduct;
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _searchController = TextEditingController();
  String _stockAction = 'reserve'; // 'reserve' or 'no_reserve'
  bool _isLoading = false;
  List<product_model.Product> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _filteredProducts = widget.products;
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = widget.products;
      } else {
        _filteredProducts = widget.products.where((product) {
          return product.name.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _onProductSelected(product_model.Product? product) async {
    setState(() {
      _selectedProduct = product;
      if (product != null) {
        _priceController.text = product.price.toString();
        // Automatically set stock action to 'no_reserve' for unlimited stock products
        if (product.unlimitedStock) {
          _stockAction = 'no_reserve';
        } else {
          _stockAction = 'reserve';
        }
      }
    });
  }

  Future<void> _addItem() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a product'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final quantity = double.tryParse(_quantityController.text);
    final price = double.tryParse(_priceController.text);

    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid quantity'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid price'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check stock if reserving (skip for unlimited stock products)
    if (!_selectedProduct!.unlimitedStock && _stockAction == 'reserve' && quantity > _selectedProduct!.stockLevel) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Insufficient Stock'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Available stock: ${_selectedProduct!.stockLevel} ${_selectedProduct!.unit}'),
              Text('Requested: $quantity ${_selectedProduct!.unit}'),
              const SizedBox(height: 12),
              const Text('Do you want to add this item without reserving stock?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Add Without Reservation'),
            ),
          ],
        ),
      );

      if (proceed != true) return;
      _stockAction = 'no_reserve';
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare order item data
      final itemData = {
        'product_name': _selectedProduct!.name,
        'quantity': quantity,
        'unit': _selectedProduct!.unit,
        'price': price,
        'stock_action': _stockAction,
      };
      
      // Add item to order
      // Note: Do NOT send 'original_text' for manually added items
      // originalText should only come from WhatsApp messages and remain immutable
      await ref.read(ordersProvider.notifier).addOrderItem(
        widget.orderId,
        itemData,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Item added successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        widget.onItemAdded();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to add item: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Item to Order'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _selectedProduct = null;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              enabled: !_isLoading,
              autofocus: true,
            ),

            const SizedBox(height: 12),

            // Product List or Selected Product Details
            if (_selectedProduct == null) ...[
              // Show filtered product list
              Expanded(
                child: _filteredProducts.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'Start typing to search products'
                              : 'No products found',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                product.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                'Stock: ${product.stockLevel} ${product.unit} | R${product.price}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              trailing: Icon(
                                product.stockLevel > 0 ? Icons.check_circle : Icons.warning,
                                color: product.stockLevel > 0 ? Colors.green : Colors.orange,
                              ),
                              onTap: _isLoading ? null : () => _onProductSelected(product),
                            ),
                          );
                        },
                      ),
              ),
            ] else ...[
              // Show selected product card
              Card(
                color: Colors.blue.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedProduct!.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _selectedProduct = null;
                                      _searchController.clear();
                                    });
                                  },
                            icon: const Icon(Icons.close, size: 20),
                            tooltip: 'Change product',
                          ),
                        ],
                      ),
                      Text(
                        'Stock: ${_selectedProduct!.stockLevel} ${_selectedProduct!.unit}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      Text(
                        'Price: R${_selectedProduct!.price}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Quantity, Price, Stock Action fields in a scrollable view
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quantity
                      const Text(
                        'Quantity',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          suffixText: _selectedProduct?.unit ?? '',
                        ),
                        enabled: !_isLoading,
                      ),

                      const SizedBox(height: 16),

                      // Price
                      const Text(
                        'Price per Unit',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          prefixText: 'R',
                        ),
                        enabled: !_isLoading,
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addItem,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Add Item'),
        ),
      ],
    );
  }
}

// Edit Item Dialog
class _EditItemDialog extends ConsumerStatefulWidget {
  final int orderId;
  final OrderItem orderItem;
  final List<product_model.Product> products;
  final VoidCallback onItemUpdated;

  const _EditItemDialog({
    required this.orderId,
    required this.orderItem,
    required this.products,
    required this.onItemUpdated,
  });

  @override
  ConsumerState<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends ConsumerState<_EditItemDialog> {
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  String _stockAction = 'reserve';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing item data
    _quantityController.text = widget.orderItem.quantity.toString();
    _priceController.text = widget.orderItem.price.toString();
    _stockAction = widget.orderItem.stockAction ?? 'reserve';
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _updateItem() async {
    final quantity = double.tryParse(_quantityController.text);
    final price = double.tryParse(_priceController.text);

    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid quantity'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid price'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare update data
      final updateData = {
        'quantity': quantity,
        'price': price,
        'unit': widget.orderItem.unit ?? widget.orderItem.product.unit,
      };
      
      // Update order item via orders provider
      await ref.read(ordersProvider.notifier).updateOrderItem(
        widget.orderId,
        widget.orderItem.id,
        updateData,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Item updated successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        widget.onItemUpdated();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to update item: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Order Item'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product info (read-only)
              Card(
                color: Colors.blue.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.orderItem.product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ordered: ${widget.orderItem.quantity} ${widget.orderItem.unit ?? widget.orderItem.product.unit}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Quantity
              const Text(
                'Quantity',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _quantityController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  suffixText: widget.orderItem.unit ?? widget.orderItem.product.unit,
                ),
                enabled: !_isLoading,
              ),
              
              const SizedBox(height: 16),
              
              // Price
              const Text(
                'Price per Unit',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  prefixText: 'R',
                ),
                enabled: !_isLoading,
              ),
              
              const SizedBox(height: 16),
              
              // Stock Action
              const Text(
                'Stock Reservation',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('Reserve Stock'),
                      subtitle: const Text('Recommended for available products'),
                      value: 'reserve',
                      groupValue: _stockAction,
                      onChanged: _isLoading ? null : (value) {
                        setState(() {
                          _stockAction = value!;
                        });
                      },
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<String>(
                      title: const Text('No Reservation'),
                      subtitle: const Text('For out-of-stock or custom items'),
                      value: 'no_reserve',
                      groupValue: _stockAction,
                      onChanged: _isLoading ? null : (value) {
                        setState(() {
                          _stockAction = value!;
                        });
                      },
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateItem,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Update Item'),
        ),
      ],
    );
  }
}

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/order.dart';

class PdfService {
  static const String _ordersSubfolder = 'Orders';

  /// Get the Documents directory path for the current platform
  static Future<Directory> _getDocumentsDirectory() async {
    if (Platform.isLinux || Platform.isMacOS) {
      final homeDir = Platform.environment['HOME'];
      if (homeDir != null) {
        final documentsDir = Directory('$homeDir/Documents');
        if (!documentsDir.existsSync()) {
          documentsDir.createSync(recursive: true);
        }
        return documentsDir;
      }
    } else if (Platform.isWindows) {
      return await getApplicationDocumentsDirectory();
    }
    
    // Fallback to application documents directory
    return await getApplicationDocumentsDirectory();
  }

  /// Get or create the date-based orders directory
  static Future<Directory> _getOrdersDirectory([DateTime? date]) async {
    final documentsDir = await _getDocumentsDirectory();
    final targetDate = date ?? DateTime.now();
    
    // Create date folder: YYYY-MM-DD format
    final dateFolder = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
    
    final ordersDir = Directory('${documentsDir.path}/$_ordersSubfolder/$dateFolder');
    
    if (!ordersDir.existsSync()) {
      print('[PDF SERVICE] Creating orders directory: ${ordersDir.path}');
      ordersDir.createSync(recursive: true);
    }
    
    return ordersDir;
  }

  /// Generate and save order PDF to date-based folder
  static Future<String?> generateOrderPdf(Order order, {DateTime? saveDate}) async {
    try {
      print('[PDF SERVICE] Generating PDF for order: ${order.orderNumber}');
      
      // Get the orders directory for the specified date (or today)
      final ordersDir = await _getOrdersDirectory(saveDate);
      
      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'Order_${order.orderNumber}_$timestamp.pdf';
      final filePath = '${ordersDir.path}/$filename';
      
      print('[PDF SERVICE] Saving to: $filePath');
      
      // Generate PDF document
      final pdf = pw.Document();
      await _buildOrderPdf(pdf, order);
      
      // Save to file
      final file = File(filePath);
      final bytes = await pdf.save();
      await file.writeAsBytes(bytes);
      
      // Verify file was created
      if (file.existsSync()) {
        final fileSize = file.lengthSync();
        print('[PDF SERVICE] ✅ PDF saved successfully!');
        print('[PDF SERVICE] File: $filePath');
        print('[PDF SERVICE] Size: $fileSize bytes');
        return filePath;
      } else {
        throw Exception('File was not created after write operation');
      }
      
    } catch (e) {
      print('[PDF SERVICE] Error generating PDF: $e');
      return null;
    }
  }

  /// Build the PDF document content using EXACT original format from order_card.dart
  static Future<void> _buildOrderPdf(pw.Document pdf, Order order) async {
    print('[PDF SERVICE] Building PDF for order: ${order.orderNumber}');
    print('[PDF SERVICE] Order has ${order.items.length} items');
    
    // Capture data BEFORE the build context
    final items = order.items;
    final restaurantName = order.restaurant.name;
    final businessName = order.restaurant.profile?.businessName ?? '';
    final deliveryAddress = order.restaurant.profile?.deliveryAddress ?? '';
    final city = order.restaurant.profile?.city ?? '';
    final postalCode = order.restaurant.profile?.postalCode ?? '';
    final phone = order.restaurant.phone ?? '';
    final orderNumber = order.orderNumber;
    final orderDate = order.orderDate;
    final deliveryDate = order.deliveryDate;
    final statusDisplay = order.statusDisplay;
    final totalAmount = order.totalAmount;
    
    print('[PDF SERVICE] Captured ${items.length} items before build context');
    
    // FIRST: Add the main order page (preview style - all items together)
    await _addMainOrderPage(pdf, items, restaurantName, businessName, deliveryAddress, city, postalCode, phone, orderNumber, orderDate, deliveryDate, statusDisplay, totalAmount);
    
    // THEN: Add sectioned pages for reserved and to order items
    final reservedItems = items.where((item) => item.isStockReserved).toList();
    final toOrderItems = items.where((item) => item.isNoReserve || item.isStockReservationFailed).toList();
    
    print('[PDF SERVICE] Reserved: ${reservedItems.length}, To Order: ${toOrderItems.length}');
    
    // Add reserved items page if there are any
    if (reservedItems.isNotEmpty) {
      // final reservedTotal = reservedItems.fold(0.0, (sum, item) => sum + item.totalPrice);
      await _addSectionPage(pdf, 'RESERVED STOCK', '✅ Stock Reserved from Inventory', reservedItems, 0.0, // reservedTotal,
          restaurantName, businessName, deliveryAddress, city, postalCode, phone, orderNumber, orderDate, deliveryDate, statusDisplay);
    }
    
    // Add to order items page if there are any
    if (toOrderItems.isNotEmpty) {
      // final toOrderTotal = toOrderItems.fold(0.0, (sum, item) => sum + item.totalPrice);
      await _addSectionPage(pdf, 'TO ORDER', '📦 Items for Procurement', toOrderItems, 0.0, // toOrderTotal,
          restaurantName, businessName, deliveryAddress, city, postalCode, phone, orderNumber, orderDate, deliveryDate, statusDisplay);
    }
  }

  /// Add main order page using EXACT original format from order_card.dart
  static Future<void> _addMainOrderPage(pw.Document pdf, List<OrderItem> items, String restaurantName, String businessName, String deliveryAddress, String city, String postalCode, String phone, String orderNumber, String orderDate, String deliveryDate, String statusDisplay, double? totalAmount) async {
    // Split items into chunks of 25 for pagination - fit more per page
    final itemsPerPage = 25;
    final totalPages = (items.length / itemsPerPage).ceil();
    
    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final startIndex = pageIndex * itemsPerPage;
      final endIndex = (startIndex + itemsPerPage).clamp(0, items.length);
      final pageItems = items.sublist(startIndex, endIndex);
      final isFirstPage = pageIndex == 0;
      final isLastPage = pageIndex == totalPages - 1;
      
      print('[PDF SERVICE] Creating main page ${pageIndex + 1}/$totalPages with ${pageItems.length} items');
    
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(16),
          build: (pw.Context context) {
            // Build item rows BEFORE the column
            final List<pw.Widget> itemRows = [];
            for (var item in pageItems) {
              itemRows.add(
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 4, child: _buildProductNameWithNotes(item)),
                      pw.Expanded(flex: 2, child: pw.Text('${item.quantity} ${item.unit ?? ''}', style: const pw.TextStyle(fontSize: 8))),
                      pw.Expanded(flex: 2, child: pw.Text(_getStockStatusText(item), style: const pw.TextStyle(fontSize: 7))),
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
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('FAMBRI FARMS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Order: $orderNumber', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Date: ${_formatDate(orderDate)}', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(restaurantName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        if (businessName.isNotEmpty) pw.Text(businessName, style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('Delivery: ${_formatDate(deliveryDate)}', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                ],
                
                // Page indicator
                if (totalPages > 1)
                  pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Text('Page ${pageIndex + 1} of $totalPages', style: const pw.TextStyle(fontSize: 8)),
                  ),
                
                pw.SizedBox(height: 8),
                
                // Table Header
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 4, child: pw.Text('Product', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(flex: 2, child: pw.Text('Quantity', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(flex: 2, child: pw.Text('Status', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                ),
                
                // Items
                ...itemRows,
                
                // Total on last page
                // if (isLastPage && totalAmount != null) ...[
                //   pw.SizedBox(height: 12),
                //   pw.Container(
                //     alignment: pw.Alignment.centerRight,
                //     child: pw.Text('Total: R${totalAmount.toStringAsFixed(2)}', 
                //       style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                //   ),
                // ],
              ],
            );
          },
        ),
      );
    }
  }

  /// Add section page using EXACT original format from order_card.dart
  static Future<void> _addSectionPage(pw.Document pdf, String sectionTitle, String sectionDescription, List<OrderItem> sectionItems, double sectionTotal, String restaurantName, String businessName, String deliveryAddress, String city, String postalCode, String phone, String orderNumber, String orderDate, String deliveryDate, String statusDisplay) async {
    // Split items into chunks for pagination
    final itemsPerPage = 30;
    final totalPages = (sectionItems.length / itemsPerPage).ceil();
    
    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final startIndex = pageIndex * itemsPerPage;
      final endIndex = (startIndex + itemsPerPage).clamp(0, sectionItems.length);
      final pageItems = sectionItems.sublist(startIndex, endIndex);
      final isFirstSectionPage = pageIndex == 0;
      final isLastSectionPage = pageIndex == totalPages - 1;
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(16),
          build: (pw.Context context) {
            // Build item rows
            final List<pw.Widget> itemRows = [];
            for (var item in pageItems) {
              itemRows.add(
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 4, child: _buildProductNameWithNotes(item)),
                      pw.Expanded(flex: 2, child: pw.Text('${item.quantity} ${item.unit ?? ''}', style: const pw.TextStyle(fontSize: 8))),
                      pw.Expanded(flex: 2, child: pw.Text(_getStockStatusText(item), style: const pw.TextStyle(fontSize: 7))),
                    ],
                  ),
                ),
              );
            }
            
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header - only on first page of section
                if (isFirstSectionPage) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(sectionTitle, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                          pw.Text(sectionDescription, style: const pw.TextStyle(fontSize: 9)),
                          pw.Text('Order: $orderNumber', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(restaurantName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Date: ${_formatDate(orderDate)}', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                ],
                
                // Page indicator for section
                if (totalPages > 1)
                  pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Text('$sectionTitle - Page ${pageIndex + 1} of $totalPages', style: const pw.TextStyle(fontSize: 8)),
                  ),
                
                pw.SizedBox(height: 8),
                
                // Table Header
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 4, child: pw.Text('Product', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(flex: 2, child: pw.Text('Quantity', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(flex: 2, child: pw.Text('Status', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                ),
                
                // Items
                ...itemRows,
                
                // Section total on last page
                if (isLastSectionPage) ...[
                  pw.SizedBox(height: 12),
                  // pw.Container(
                  //   alignment: pw.Alignment.centerRight,
                  //   child: pw.Text('$sectionTitle Total: R${sectionTotal.toStringAsFixed(2)}',
                  //     style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  // ),
                ],
              ],
            );
          },
        ),
      );
    }
  }

  /// Helper methods from original order_card.dart
  static String _getStockStatusText(OrderItem item) {
    if (item.isStockReserved) {
      return 'Reserved';
    } else if (item.isConvertedToBulkKg) {
      return 'Converted to Kg';
    } else if (item.isNoReserve) {
      return 'To Order';
    } else if (item.isStockReservationFailed) {
      return 'Need to Order';
    } else {
      return 'Unknown';
    }
  }

  static pw.Widget _buildProductNameWithNotes(OrderItem item) {
    // Check if this is a split item based on notes
    bool isSplitItem = item.notes?.contains('Split item') == true;
    
    if (isSplitItem) {
      String splitInfo = '';
      if (item.notes?.contains('Reserved from stock') == true) {
        splitInfo = '[Reserved Part]';
      } else if (item.notes?.contains('Needs procurement') == true) {
        splitInfo = '[To Order Part]';
      }
      
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(item.product.name, style: const pw.TextStyle(fontSize: 8)),
          if (splitInfo.isNotEmpty)
            pw.Text(splitInfo, style: pw.TextStyle(fontSize: 6, color: PdfColors.blue700)),
        ],
      );
    }
    
    return pw.Text(item.product.name, style: const pw.TextStyle(fontSize: 8));
  }

  /// Helper methods
  static String _formatDate(String dateString) {
    try {
      // Try to parse the date string and format it
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      // If parsing fails, return the original string
      return dateString;
    }
  }

  static String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  static String _getItemStatus(OrderItem item) {
    if (item.isStockReserved) return 'Reserved';
    if (item.isNoReserve) return 'No Reserve';
    if (item.isStockReservationFailed) return 'Failed Reserve';
    return 'Pending';
  }
}
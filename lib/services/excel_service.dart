import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import '../models/order.dart';

class ExcelService {
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
      print('[EXCEL SERVICE] Creating orders directory: ${ordersDir.path}');
      ordersDir.createSync(recursive: true);
    }
    
    return ordersDir;
  }

  /// Generate and save order Excel to date-based folder
  static Future<String?> generateOrderExcel(Order order, {DateTime? saveDate}) async {
    try {
      print('[EXCEL SERVICE] Generating Excel for order: ${order.orderNumber}');
      
      // Get the orders directory for the specified date (or today)
      final ordersDir = await _getOrdersDirectory(saveDate);
      
      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'Order_${order.orderNumber}_$timestamp.xlsx';
      final filePath = '${ordersDir.path}/$filename';
      
      print('[EXCEL SERVICE] Saving to: $filePath');
      
      // Generate Excel document
      final excel = Excel.createExcel();
      await _buildOrderExcel(excel, order);
      
      // Save to file
      final excelBytes = excel.save();
      if (excelBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(excelBytes);
        
        // Verify file was created
        if (file.existsSync()) {
          final fileSize = file.lengthSync();
          print('[EXCEL SERVICE] ✅ Excel saved successfully!');
          print('[EXCEL SERVICE] File: $filePath');
          print('[EXCEL SERVICE] Size: $fileSize bytes');
          return filePath;
        } else {
          throw Exception('File was not created after write operation');
        }
      } else {
        throw Exception('Failed to generate Excel bytes');
      }
      
    } catch (e) {
      print('[EXCEL SERVICE] Error generating Excel: $e');
      return null;
    }
  }

  /// Build the Excel document content
  static Future<void> _buildOrderExcel(Excel excel, Order order) async {
    print('[EXCEL SERVICE] Building Excel for order: ${order.orderNumber}');
    print('[EXCEL SERVICE] Order has ${order.items.length} items');
    
    // Remove default sheet if it exists
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    
    // Create main order sheet
    final sheet = excel['Order ${order.orderNumber}'];
    
    // Add order header information
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('ORDER DETAILS');
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
    );
    
    // Order information
    int currentRow = 3;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('Order Number:');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = TextCellValue(order.orderNumber);
    currentRow++;
    
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('Restaurant:');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = TextCellValue(order.restaurant.name);
    currentRow++;
    
    if (order.restaurant.profile?.businessName?.isNotEmpty == true) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('Business Name:');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = TextCellValue(order.restaurant.profile!.businessName!);
      currentRow++;
    }
    
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('Order Date:');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = TextCellValue(order.orderDate);
    currentRow++;
    
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('Delivery Date:');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = TextCellValue(order.deliveryDate);
    currentRow++;
    
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('Status:');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = TextCellValue(order.statusDisplay);
    currentRow++;
    
    // sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('Total Amount:');
    // sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = TextCellValue('R${order.totalAmount?.toStringAsFixed(2) ?? '0.00'}');
    currentRow += 2;
    
    // Contact information
    if (order.restaurant.phone?.isNotEmpty == true || 
        order.restaurant.profile?.deliveryAddress?.isNotEmpty == true) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('CONTACT INFORMATION');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
      );
      currentRow++;
      
      if (order.restaurant.phone?.isNotEmpty == true) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('Phone:');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = TextCellValue(order.restaurant.phone!);
        currentRow++;
      }
      
      if (order.restaurant.profile?.deliveryAddress?.isNotEmpty == true) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('Address:');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = TextCellValue(order.restaurant.profile!.deliveryAddress!);
        currentRow++;
      }
      
      if (order.restaurant.profile?.city?.isNotEmpty == true) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('City:');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = TextCellValue(order.restaurant.profile!.city!);
        currentRow++;
      }
      
      if (order.restaurant.profile?.postalCode?.isNotEmpty == true) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('Postal Code:');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = TextCellValue(order.restaurant.profile!.postalCode!);
        currentRow++;
      }
      
      currentRow++;
    }
    
    // Order items table
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('ORDER ITEMS');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
    );
    currentRow += 2;
    
    // Table headers
    final headers = ['Product', 'Quantity', 'Unit', /* 'Unit Price', 'Total Price', */ 'Stock Status', 'Notes'];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = TextCellValue(headers[i]);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );
    }
    currentRow++;
    
    // Add order items
    // double totalAmount = 0.0;
    for (final item in order.items) {
      // final itemTotal = item.quantity * item.price;
      // totalAmount += itemTotal;
      
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
        TextCellValue(productName),
        DoubleCellValue(item.quantity),
        TextCellValue(item.product.unit),
        // DoubleCellValue(item.price),
        // DoubleCellValue(itemTotal),
        TextCellValue(stockStatus),
        TextCellValue(item.notes ?? ''),
      ];
      
      for (int i = 0; i < rowData.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = rowData[i];
      }
      currentRow++;
    }
    
    // Total row
    // currentRow++;
    // sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).value = TextCellValue('TOTAL:');
    // sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).cellStyle = CellStyle(bold: true);
    // sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).value = DoubleCellValue(totalAmount);
    // sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).cellStyle = CellStyle(
    //   bold: true,
    // );
    
    // Auto-fit columns
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnAutoFit(i);
    }
    
    print('[EXCEL SERVICE] Excel document built successfully');
  }
}

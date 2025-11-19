import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import '../models/order.dart';
import '../models/product.dart' as product_model;

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
  static Future<String?> generateOrderExcel(Order order, {DateTime? saveDate, List<product_model.Product>? products}) async {
    try {
      print('[EXCEL SERVICE] Generating Excel for order: ${order.orderNumber}');
      
      // Get the orders directory for the specified date (or today)
      final ordersDir = await _getOrdersDirectory(saveDate);
      
      // Generate unique filename with business name and timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Use business name from profile, fallback to restaurant name
      final businessName = (order.restaurant?.profile?.businessName ?? order.restaurant?.name ?? 'Unknown')
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(' ', '_');
      final filename = '${businessName}_${order.orderNumber}_$timestamp.xlsx';
      final filePath = '${ordersDir.path}/$filename';
      
      print('[EXCEL SERVICE] Saving to: $filePath');
      
      // Generate Excel document
      final excel = Excel.createExcel();
      await _buildOrderExcel(excel, order, products);
      
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
  static Future<void> _buildOrderExcel(Excel excel, Order order, List<product_model.Product>? products) async {
    print('[EXCEL SERVICE] Building Excel for order: ${order.orderNumber}');
    print('[EXCEL SERVICE] Order has ${order.items.length} items');
    
    // Debug: List all sheets before creating custom sheet
    print('[EXCEL SERVICE] Sheets before creating custom sheet: ${excel.sheets.keys.toList()}');
    
    // Create main order sheet first
    final sheet = excel['Order ${order.orderNumber}'];
    
    // Debug: List all sheets after creating custom sheet
    print('[EXCEL SERVICE] Sheets after creating custom sheet: ${excel.sheets.keys.toList()}');
    
    // Remove default sheet AFTER creating our custom sheet
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
      print('[EXCEL SERVICE] Removed default Sheet1');
      print('[EXCEL SERVICE] Final sheets: ${excel.sheets.keys.toList()}');
    } else {
      print('[EXCEL SERVICE] No Sheet1 found to remove');
      print('[EXCEL SERVICE] Final sheets: ${excel.sheets.keys.toList()}');
    }
    
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
    
    // Table headers - add Errors column
    final headers = ['Product', 'Quantity', 'Unit', /* 'Unit Price', 'Total Price', */ 'Stock Status', 'Errors/Issues', 'Notes'];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = TextCellValue(headers[i]);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );
    }
    currentRow++;
    
    // Add order items (sorted alphabetically)
    // double totalAmount = 0.0;
    final sortedItems = [...order.items];
    sortedItems.sort((a, b) => a.product.name.toLowerCase().compareTo(b.product.name.toLowerCase()));
    
    for (final item in sortedItems) {
      // final itemTotal = item.quantity * item.price;
      // totalAmount += itemTotal;
      
      // Product name with source product info and notes
      String productName = item.product.name;
      if (item.sourceProductName != null && item.sourceQuantity != null) {
        productName += ' [Stock from: ${item.sourceProductName} (${item.sourceQuantity}${item.sourceProductUnit ?? ''})]';
      }
      if (item.notes?.isNotEmpty == true) {
        productName += ' (${item.notes})';
      }
      
      // Stock status - check if product is always available
      String stockStatus = 'Unknown';
      final product = products?.firstWhere(
        (p) => p.id == item.product.id,
        orElse: () => product_model.Product(
          id: item.product.id,
          name: item.product.name,
          department: 'Other',
          price: item.product.price,
          unit: item.product.unit,
        ),
      );
      
      if (product?.unlimitedStock == true) {
        stockStatus = '🌱 Always Available';
      } else if (item.isStockReserved) {
        stockStatus = 'Reserved';
      } else if (item.isNoReserve) {
        stockStatus = 'No Reserve';
      } else if (item.isStockReservationFailed) {
        stockStatus = 'Reservation Failed';
      }
      
      // If using source product, show that source product stock is reserved
      if (item.sourceProductId != null && item.sourceProductName != null && item.sourceQuantity != null) {
        stockStatus = 'Stock Reserved from Source';
      }
      
      // Extract error information from stockResult
      String errorField = '';
      final List<String> errors = [];
      
      // Check for stock reservation failures
      if (item.isStockReservationFailed && item.stockResult != null) {
        final message = item.stockResult!['message'] as String?;
        if (message != null && message.isNotEmpty) {
          errors.add('Stock Reservation Failed: $message');
        } else {
          errors.add('Stock Reservation Failed: Insufficient stock available');
        }
        
        // Check for available stock info
        final availableStock = item.stockResult!['available_stock'];
        if (availableStock != null) {
          errors.add('Available Stock: $availableStock ${item.product.unit}');
        }
        
        // Check for required quantity
        final requiredQuantity = item.stockResult!['required_quantity'];
        if (requiredQuantity != null) {
          errors.add('Required: $requiredQuantity ${item.product.unit}');
        }
      }
      
      // Check for source product issues
      if (item.sourceProductId != null && item.sourceProductName != null) {
        // Check if source product stock is insufficient
        if (item.sourceProductStockLevel != null && item.sourceQuantity != null) {
          if (item.sourceQuantity > item.sourceProductStockLevel!) {
            errors.add('Source Product Insufficient: ${item.sourceProductName} has ${item.sourceProductStockLevel}${item.sourceProductUnit ?? ''}, need ${item.sourceQuantity}${item.sourceProductUnit ?? ''}');
          }
        }
      }
      
      // Check for conversion issues
      if (item.isConvertedToBulkKg && item.stockResult != null) {
        final conversionMessage = item.stockResult!['message'] as String?;
        if (conversionMessage != null && conversionMessage.isNotEmpty) {
          errors.add('Conversion: $conversionMessage');
        }
      }
      
      // Check for no reserve items that might need attention
      if (item.isNoReserve && item.product.stockLevel != null && item.product.stockLevel! <= 0) {
        errors.add('No Stock Available: Product is out of stock and no reservation was made');
      }
      
      errorField = errors.join('\n');
      
      // Build notes field with original text if available
      String notesField = '';
      if (item.originalText != null && item.originalText!.isNotEmpty) {
        notesField = 'Original: ${item.originalText}';
        if (item.notes?.isNotEmpty == true) {
          notesField += '\n${item.notes}';
        }
      } else if (item.notes?.isNotEmpty == true) {
        notesField = item.notes!;
      }
      
      // Add source product reservation info to notes
      if (item.sourceProductName != null && item.sourceQuantity != null) {
        if (notesField.isNotEmpty) {
          notesField += '\n';
        }
        notesField += 'Source Product Reserved: ${item.sourceProductName} (${item.sourceQuantity}${item.sourceProductUnit ?? ''})';
      }
      
      final rowData = [
        TextCellValue(productName),
        DoubleCellValue(item.quantity),
        TextCellValue(item.product.unit),
        // DoubleCellValue(item.price),
        // DoubleCellValue(itemTotal),
        TextCellValue(stockStatus),
        TextCellValue(errorField),  // Errors/Issues column
        TextCellValue(notesField),
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
    
    // Create additional sheets if products data is available
    if (products != null) {
      print('[EXCEL SERVICE] Products list has ${products.length} products');
      await _buildReservedStockSheet(excel, order, products);
      await _buildStockToOrderSheet(excel, order, products);
      await _buildErrorsSheet(excel, order, products);
    } else {
      print('[EXCEL SERVICE] WARNING: Products list is null - Stock to Order sheet will not be created');
    }
    
    print('[EXCEL SERVICE] Excel document built successfully');
  }

  /// Build the Reserved Stock sheet
  static Future<void> _buildReservedStockSheet(Excel excel, Order order, List<product_model.Product> products) async {
    print('[EXCEL SERVICE] Building Reserved Stock sheet');
    
    final sheet = excel['Reserved Stock'];
    
    // Sheet title
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('RESERVED STOCK');
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
    );
    
    // Order info
    int currentRow = 3;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('Order Number:');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = TextCellValue(order.orderNumber);
    currentRow++;
    
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('Restaurant:');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = TextCellValue(order.restaurant.name);
    currentRow += 2;
    
    // Table headers
    final headers = ['Product', 'Ordered Qty', 'Unit', 'Reserved Qty', 'Stock Level', 'Status'];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = TextCellValue(headers[i]);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );
    }
    currentRow++;
    
    // Add reserved stock items (sorted alphabetically)
    // Include both directly reserved items AND source products that are reserved
    final reservedItems = order.items.where((item) => item.isStockReserved).toList();
    reservedItems.sort((a, b) => a.product.name.toLowerCase().compareTo(b.product.name.toLowerCase()));
    
    // Track which products we've already added to avoid duplicates
    final addedProductIds = <int>{};
    
    for (final item in reservedItems) {
      // Find corresponding product in products list
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
        TextCellValue(item.product.name),
        DoubleCellValue(item.quantity),
        TextCellValue(item.product.unit),
        DoubleCellValue(item.quantity), // Assuming full quantity is reserved
        DoubleCellValue(product.stockLevel),
        TextCellValue('✅ Reserved'),
      ];
      
      for (int i = 0; i < rowData.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = rowData[i];
      }
      currentRow++;
      addedProductIds.add(item.product.id);
    }
    
    // Add source products that are reserved (for items using stock from another product)
    final sourceProductItems = order.items.where((item) => 
      item.sourceProductId != null && 
      item.sourceProductName != null && 
      item.sourceQuantity != null
    ).toList();
    
    for (final item in sourceProductItems) {
      // Skip if we already added this source product
      if (addedProductIds.contains(item.sourceProductId)) {
        continue;
      }
      
      // Find source product in products list
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
        TextCellValue('${item.sourceProductName} (Source)'),
        DoubleCellValue(item.sourceQuantity ?? 0),
        TextCellValue(item.sourceProductUnit ?? 'kg'),
        DoubleCellValue(item.sourceQuantity ?? 0), // Reserved quantity from source
        DoubleCellValue(sourceProduct.stockLevel),
        TextCellValue('✅ Reserved (for ${item.product.name})'),
      ];
      
      for (int i = 0; i < rowData.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = rowData[i];
      }
      currentRow++;
      addedProductIds.add(item.sourceProductId!);
    }
    
    // If no reserved items, show message
    if (reservedItems.isEmpty && sourceProductItems.isEmpty) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('No items have reserved stock');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = CellStyle(
        italic: true,
      );
    }
    
    // Auto-fit columns
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnAutoFit(i);
    }
    
    print('[EXCEL SERVICE] Reserved Stock sheet built successfully');
  }

  /// Build the Stock to Order sheet
  static Future<void> _buildStockToOrderSheet(Excel excel, Order order, List<product_model.Product> products) async {
    print('[EXCEL SERVICE] Building Stock to Order sheet');
    
    final sheet = excel['Stock to Order'];
    
    // Sheet title
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('STOCK TO ORDER');
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
    );
    
    // Order info
    int currentRow = 3;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('Order Number:');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = TextCellValue(order.orderNumber);
    currentRow++;
    
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('Restaurant:');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = TextCellValue(order.restaurant.name);
    currentRow += 2;
    
    // Table headers
    final headers = ['Product', 'Ordered Qty', 'Unit', 'Current Stock', 'Shortage', 'Need to Order', 'Status'];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = TextCellValue(headers[i]);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );
    }
    currentRow++;
    
    // Filter items that need to be ordered (no reserve or failed reservation)
    // Exclude unlimited stock products (they're always available)
    print('[EXCEL SERVICE] Filtering items for Stock to Order...');
    print('[EXCEL SERVICE] Order has ${order.items.length} items total');
    print('[EXCEL SERVICE] Products list has ${products.length} products');
    
    final itemsToOrder = order.items.where((item) {
      final stockActionStr = item.stockAction?.toString() ?? 'null';
      final stockResultStr = item.stockResult?.toString() ?? 'null';
      print('[EXCEL SERVICE]   - ${item.product.name}: stockAction=$stockActionStr, isNoReserve=${item.isNoReserve}, isFailed=${item.isStockReservationFailed}, stockResult=$stockResultStr');
      
      // Find corresponding product to check unlimited stock first
      final product = products.firstWhere(
        (p) => p.id == item.product.id,
        orElse: () {
          print('[EXCEL SERVICE]     -> WARNING: Product ${item.product.name} (ID: ${item.product.id}) not found in products list, creating fallback');
          return product_model.Product(
            id: item.product.id,
            name: item.product.name,
            department: 'Other',
            price: item.product.price,
            unit: item.product.unit,
            stockLevel: 0,
            minimumStock: 0,
          );
        },
      );
      
      // Skip unlimited stock products (they're always available, no need to order)
      if (product.unlimitedStock) {
        print('[EXCEL SERVICE]     -> Skipping ${item.product.name} (unlimited stock)');
        return false;
      }
      
      // Check if this item needs to be ordered:
      // 1. Stock reservation failed (out of stock)
      // 2. No reservation was made (intentional no-reserve for bulk items)
      // Also check stockAction directly as fallback
      final stockAction = item.stockAction;
      final isNoReserve = item.isNoReserve || stockAction == 'no_reserve';
      final isFailed = item.isStockReservationFailed || 
          (stockAction == 'reserve' && item.stockResult != null && 
           !(item.stockResult!['success'] as bool? ?? true));
      final needsOrdering = isFailed || isNoReserve;
      
      if (needsOrdering) {
        print('[EXCEL SERVICE]     -> ✅ WILL ADD ${item.product.name} to Stock to Order sheet (isNoReserve=$isNoReserve, isFailed=$isFailed, stockAction=$stockAction)');
        return true;
      } else {
        print('[EXCEL SERVICE]     -> ❌ Skipping ${item.product.name} (stockAction=$stockAction, isNoReserve=${item.isNoReserve}, isFailed=${item.isStockReservationFailed})');
        return false;
      }
    }).toList();
    
    // Sort alphabetically
    itemsToOrder.sort((a, b) => a.product.name.toLowerCase().compareTo(b.product.name.toLowerCase()));
    
    print('[EXCEL SERVICE] Found ${itemsToOrder.length} items to order');
    
    // Add items to sheet
    for (final item in itemsToOrder) {
      // Find corresponding product in products list
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
      
      final shortage = (item.quantity - product.stockLevel).clamp(0.0, double.infinity).toDouble();
      
      // Use same fallback logic for status determination
      final isNoReserve = item.isNoReserve || item.stockAction == 'no_reserve';
      final isFailed = item.isStockReservationFailed || 
          (item.stockAction == 'reserve' && item.stockResult != null && 
           !(item.stockResult!['success'] as bool? ?? true));
      
      String status = '';
      if (isFailed) {
        status = '❌ Reservation Failed';
      } else if (isNoReserve) {
        status = '🔓 No Reservation';
      } else if (shortage > 0) {
        status = '📦 Insufficient Stock';
      }
      
      final rowData = [
        TextCellValue(item.product.name),
        DoubleCellValue(item.quantity),
        TextCellValue(item.product.unit),
        DoubleCellValue(product.stockLevel),
        DoubleCellValue(shortage),
        DoubleCellValue(shortage > 0 ? shortage : item.quantity),
        TextCellValue(status),
      ];
      
      print('[EXCEL SERVICE] Writing row $currentRow: ${item.product.name}');
      for (int i = 0; i < rowData.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = rowData[i];
      }
      currentRow++;
    }
    
    final hasItemsToOrder = itemsToOrder.isNotEmpty;
    
    if (!hasItemsToOrder) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('All items are available in stock');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = CellStyle(
        italic: true,
      );
    }
    
    // Auto-fit columns
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnAutoFit(i);
    }
    
    print('[EXCEL SERVICE] Stock to Order sheet built successfully');
  }

  /// Build the Errors sheet - lists all items with errors/issues
  static Future<void> _buildErrorsSheet(Excel excel, Order order, List<product_model.Product> products) async {
    print('[EXCEL SERVICE] Building Errors sheet');
    
    // Filter items with errors
    final itemsWithErrors = order.items.where((item) {
      // Check for stock reservation failures
      if (item.isStockReservationFailed) return true;
      
      // Check for source product issues
      if (item.sourceProductId != null && item.sourceProductStockLevel != null && item.sourceQuantity != null) {
        if (item.sourceQuantity > item.sourceProductStockLevel!) return true;
      }
      
      // Check for no reserve items with no stock
      if (item.isNoReserve && item.product.stockLevel != null && item.product.stockLevel! <= 0) return true;
      
      return false;
    }).toList();
    
    // If no errors, skip creating the sheet
    if (itemsWithErrors.isEmpty) {
      print('[EXCEL SERVICE] No items with errors - skipping Errors sheet');
      return;
    }
    
    final sheet = excel['Errors'];
    
    // Sheet title
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('ITEMS WITH ERRORS/ISSUES');
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
    );
    
    // Order info
    int currentRow = 3;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('Order Number:');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = TextCellValue(order.orderNumber);
    currentRow++;
    
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('Restaurant:');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = TextCellValue(order.restaurant.name);
    currentRow += 2;
    
    // Table headers
    final headers = ['Product', 'Quantity', 'Unit', 'Error Type', 'Error Details', 'Action Required'];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = TextCellValue(headers[i]);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColor: excel.Color.fromHex('#FFE6E6'), // Light red background
      );
    }
    currentRow++;
    
    // Add error items
    for (final item in itemsWithErrors) {
      String errorType = 'Unknown';
      String errorDetails = '';
      String actionRequired = '';
      
      // Determine error type and details
      if (item.isStockReservationFailed && item.stockResult != null) {
        errorType = 'Stock Reservation Failed';
        final message = item.stockResult!['message'] as String?;
        if (message != null && message.isNotEmpty) {
          errorDetails = message;
        } else {
          errorDetails = 'Insufficient stock available';
        }
        
        // Add stock details
        final availableStock = item.stockResult!['available_stock'];
        final requiredQuantity = item.stockResult!['required_quantity'];
        if (availableStock != null || requiredQuantity != null) {
          errorDetails += '\n';
          if (availableStock != null) {
            errorDetails += 'Available: $availableStock ${item.product.unit}\n';
          }
          if (requiredQuantity != null) {
            errorDetails += 'Required: $requiredQuantity ${item.product.unit}';
          }
        }
        
        actionRequired = 'Order stock or find alternative product';
      } else if (item.sourceProductId != null && item.sourceProductStockLevel != null && item.sourceQuantity != null) {
        if (item.sourceQuantity > item.sourceProductStockLevel!) {
          errorType = 'Source Product Insufficient';
          errorDetails = 'Source product ${item.sourceProductName} has insufficient stock.\n'
              'Available: ${item.sourceProductStockLevel}${item.sourceProductUnit ?? ''}\n'
              'Required: ${item.sourceQuantity}${item.sourceProductUnit ?? ''}';
          actionRequired = 'Check source product stock or use different source';
        }
      } else if (item.isNoReserve && item.product.stockLevel != null && item.product.stockLevel! <= 0) {
        errorType = 'No Stock Available';
        errorDetails = 'Product is out of stock and no reservation was made.\n'
            'Current Stock: ${item.product.stockLevel} ${item.product.unit}';
        actionRequired = 'Order stock or confirm customer wants to proceed without stock';
      }
      
      final rowData = [
        TextCellValue(item.product.name),
        DoubleCellValue(item.quantity),
        TextCellValue(item.product.unit ?? ''),
        TextCellValue(errorType),
        TextCellValue(errorDetails),
        TextCellValue(actionRequired),
      ];
      
      for (int i = 0; i < rowData.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
        cell.value = rowData[i];
        // Highlight error rows with light red background
        if (i == 0) { // Only apply to first cell to avoid over-styling
          cell.cellStyle = CellStyle(
            backgroundColor: excel.Color.fromHex('#FFF0F0'),
          );
        }
      }
      currentRow++;
    }
    
    // Auto-fit columns
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnAutoFit(i);
    }
    
    print('[EXCEL SERVICE] Errors sheet built successfully with ${itemsWithErrors.length} items');
  }
}

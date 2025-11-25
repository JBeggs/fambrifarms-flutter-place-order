import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as excel;
import '../../../models/product.dart';
import '../../../utils/stock_formatter.dart';

/// Handles PDF and Excel generation for bulk stock take reports
class BulkStockTakePdfGenerator {
  /// Generate a PDF report for stock take entries
  static Future<String?> generateStockTakePdf({
    required List<Map<String, dynamic>> entries,
    required List<Product> stockTakeProducts,
  }) async {
    try {
      print('[STOCK_TAKE_PDF] Generating PDF for ${entries.length} entries');
      
      final sortedEntries = _sortEntries(entries, stockTakeProducts);
      print('[STOCK_TAKE_PDF] Sorted ${sortedEntries.length} entries alphabetically');
      
      final now = DateTime.now();
      final filename = _generateFilename('BulkStockTake', 'pdf', now);
      
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          build: (context) => [
            _buildPdfHeader(now),
            pw.SizedBox(height: 16),
            _buildPdfTableHeader(),
            ..._buildPdfTableRows(sortedEntries, stockTakeProducts),
            pw.SizedBox(height: 16),
            _buildPdfSummary(entries),
          ],
        ),
      );
      
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(await pdf.save());
      
      print('[STOCK_TAKE_PDF] PDF saved to: ${file.path}');
      return file.path;
    } catch (e) {
      print('[STOCK_TAKE_PDF] Error generating PDF: $e');
      return null;
    }
  }
  
  /// Generate an Excel report for stock take entries
  static Future<String?> generateStockTakeExcel({
    required List<Map<String, dynamic>> entries,
    required List<Product> stockTakeProducts,
  }) async {
    try {
      print('[STOCK_TAKE_EXCEL] Generating Excel for ${entries.length} entries');
      
      final sortedEntries = _sortEntries(entries, stockTakeProducts);
      print('[STOCK_TAKE_EXCEL] Sorted ${sortedEntries.length} entries alphabetically');
      
      final now = DateTime.now();
      final filename = _generateFilename('BulkStockTake', 'xlsx', now);
      
      final excelFile = excel.Excel.createExcel();
      final sheet = excelFile['Stock Take'];
      
      // Remove default sheet if it exists
      if (excelFile.sheets.containsKey('Sheet1')) {
        excelFile.delete('Sheet1');
      }
      
      // Add header row
      _addExcelHeader(sheet);
      
      // Add data rows
      for (final entry in sortedEntries) {
        _addExcelDataRow(sheet, entry, stockTakeProducts);
      }
      
      // Add Errors sheet if there are any errors
      _addErrorsSheet(excelFile, sortedEntries, stockTakeProducts);
      
      // Auto-fit columns
      for (int i = 0; i < 9; i++) {  // Updated from 8 to 9 for new Errors/Issues column
        sheet.setColumnAutoFit(i);
      }
      
      // Save Excel file
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$filename');
      final bytes = excelFile.encode();
      
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        print('[STOCK_TAKE_EXCEL] Excel saved to: ${file.path}');
        return file.path;
      } else {
        print('[STOCK_TAKE_EXCEL] Failed to encode Excel file');
        return null;
      }
    } catch (e) {
      print('[STOCK_TAKE_EXCEL] Error generating Excel: $e');
      return null;
    }
  }
  
  // ========== PRIVATE HELPERS ==========
  
  /// Sort entries alphabetically by product name
  static List<Map<String, dynamic>> _sortEntries(
    List<Map<String, dynamic>> entries,
    List<Product> stockTakeProducts,
  ) {
    final sorted = List<Map<String, dynamic>>.from(entries);
    sorted.sort((a, b) {
      final productA = stockTakeProducts.where((p) => p.id == a['product_id']).firstOrNull;
      final productB = stockTakeProducts.where((p) => p.id == b['product_id']).firstOrNull;
      if (productA == null || productB == null) return 0;
      return productA.name.toLowerCase().compareTo(productB.name.toLowerCase());
    });
    return sorted;
  }
  
  /// Generate standardized filename with timestamp
  static String _generateFilename(String prefix, String extension, DateTime now) {
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return '${prefix}_${dateStr}_$timeStr.$extension';
  }
  
  // ========== PDF BUILDERS ==========
  
  static pw.Widget _buildPdfHeader(DateTime now) {
    final dateStr = '${now.day}/${now.month}/${now.year}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 2, color: PdfColors.blue700)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Stock Take Report',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated: $dateStr at $timeStr',
                style: pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildPdfTableHeader() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: const pw.BoxDecoration(
        color: PdfColors.blue100,
        border: pw.Border(
          bottom: pw.BorderSide(width: 2, color: PdfColors.blue700),
          top: pw.BorderSide(width: 1, color: PdfColors.blue300),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 4,
            child: pw.Text(
              'Product',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
                color: PdfColors.blue900,
              ),
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Stock Counted',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                  color: PdfColors.blue900,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Weight (kg)',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                  color: PdfColors.blue900,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ),
          pw.Expanded(
            flex: 1,
            child: pw.Text(
              'Unit',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
                color: PdfColors.blue900,
              ),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              'Comment',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
                color: PdfColors.blue900,
              ),
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Wastage Qty',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                  color: PdfColors.blue900,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ),
          pw.Expanded(
            flex: 2, 
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Wastage Weight (kg)',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                  color: PdfColors.blue900,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              'Reason',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
                color: PdfColors.blue900,
              ),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              'Errors/Issues',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
                color: PdfColors.blue900,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  static List<pw.Widget> _buildPdfTableRows(
    List<Map<String, dynamic>> entries,
    List<Product> stockTakeProducts,
  ) {
    return entries.asMap().entries.map((entryWithIndex) {
      final entry = entryWithIndex.value;
      final rowIndex = entryWithIndex.key;
      final productId = entry['product_id'] as int;
      final product = stockTakeProducts.where((p) => p.id == productId).firstOrNull;
      
      if (product == null) {
        print('[PDF] ERROR: Product with ID $productId not found');
        return pw.Container();
      }
      
      final countedStock = entry['counted_quantity'] as double;
      final weight = entry['weight'] as double? ?? 0.0;
      final wastageQuantity = entry['wastage_quantity'] as double? ?? 0.0;
      final wastageWeight = entry['wastage_weight'] as double? ?? 0.0;
      final wastageReason = entry['wastage_reason'] as String? ?? '';
      final comment = entry['comment'] as String? ?? '';
      
      // Add indicator for unlimited stock products
      final productName = product.unlimitedStock 
          ? '🌱 ${product.name}'
          : product.name;
      
      // Format stock counted - show count only (not combined with weight)
      // For discrete units: show whole numbers
      // For continuous units: show decimals
      final productUnit = (product.unit ?? '').toLowerCase().trim();
      final stockCountedDisplay = (productUnit == 'kg' || productUnit == 'g' || productUnit == 'ml' || productUnit == 'l')
          ? (countedStock > 0 ? countedStock.toStringAsFixed(1) : '0.0')
          : (countedStock > 0 ? countedStock.toInt().toString() : '0');
      
      final commentDisplay = comment.isNotEmpty ? comment : '-';
      
      // Extract error information
      String errorField = '';
      final List<String> errors = [];
      
      // Check for missing required data
      final isKgProduct = productUnit == 'kg';
      
      if (isKgProduct && weight <= 0) {
        errors.add('Missing Required Data: Weight is required for kg products');
      } else if (!isKgProduct && countedStock <= 0) {
        // For discrete units: count is required, weight is optional (for audit trail)
        errors.add('Missing Required Data: Quantity (count) is required for ${productUnit} products');
      }
      
      // Check for wastage without reason
      if ((wastageQuantity > 0 || wastageWeight > 0) && wastageReason.isEmpty) {
        errors.add('Wastage Recorded: Wastage quantity/weight entered but no reason provided');
      }
      
      errorField = errors.join('; ');
      
      // Alternate row colors for better readability
      final isEvenRow = rowIndex % 2 == 0;
      
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(
          color: isEvenRow ? PdfColors.white : PdfColors.grey50,
          border: const pw.Border(
            bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
          ),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Product name
            pw.Expanded(
              flex: 4,
              child: pw.Text(
                productName, 
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                  color: PdfColors.grey900,
                ),
              ),
            ),
            // Stock Counted - shows count for discrete units, weight for continuous units (right-aligned)
            pw.Expanded(
              flex: 2,
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  stockCountedDisplay,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.normal,
                    color: PdfColors.grey900,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ),
            // Weight (kg)
            pw.Expanded(
              flex: 2,
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  weight > 0 
                    ? weight.toStringAsFixed(1)
                    : '-',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.normal,
                    color: weight > 0 ? PdfColors.grey900 : PdfColors.grey500,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ),
            // Unit
            pw.Expanded(
              flex: 1,
              child: pw.Text(
                product.unit,
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            // Comment
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                commentDisplay,
                style: pw.TextStyle(
                  fontSize: 10,
                  color: comment.isNotEmpty ? PdfColors.grey800 : PdfColors.grey400,
                ),
                maxLines: 2,
              ),
            ),
            // Wastage Quantity
            pw.Expanded(
              flex: 2,
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  wastageQuantity > 0 
                    ? (wastageQuantity % 1 == 0 ? wastageQuantity.toInt().toString() : wastageQuantity.toStringAsFixed(1))
                    : '-',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: wastageQuantity > 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: wastageQuantity > 0 ? PdfColors.red700 : PdfColors.grey400,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ),
            // Wastage Weight (kg)
            pw.Expanded(
              flex: 2,
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  wastageWeight > 0 
                    ? wastageWeight.toStringAsFixed(1)
                    : '-',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: wastageWeight > 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: wastageWeight > 0 ? PdfColors.red700 : PdfColors.grey400,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ),
            // Wastage Reason
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                wastageReason.isNotEmpty ? wastageReason : '-',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: wastageReason.isNotEmpty ? PdfColors.grey800 : PdfColors.grey400,
                ),
                maxLines: 2,
              ),
            ),
            // Errors/Issues
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                errorField.isNotEmpty ? errorField : '-',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: errorField.isNotEmpty ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: errorField.isNotEmpty ? PdfColors.red700 : PdfColors.grey400,
                ),
                maxLines: 3,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
  
  static pw.Widget _buildPdfSummary(List<Map<String, dynamic>> entries) {
    final productsWithWastage = entries.where((e) => 
      (e['wastage_quantity'] as double? ?? 0.0) > 0 || 
      (e['wastage_weight'] as double? ?? 0.0) > 0
    ).length;
    
    final totalWastageWeight = entries.fold<double>(
      0.0,
      (sum, e) => sum + (e['wastage_weight'] as double? ?? 0.0),
    );
    
    final productsWithErrors = entries.where((e) {
      final productId = e['product_id'] as int;
      // This is a simplified check - actual error detection happens in _buildPdfTableRows
      return false; // Will be calculated properly if needed
    }).length;
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.blue300, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Total Products',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '${entries.length}',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Products with Wastage',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '$productsWithWastage',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: productsWithWastage > 0 ? PdfColors.red700 : PdfColors.blue900,
                ),
              ),
            ],
          ),
          pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
              pw.Text(
                'Total Wastage Weight',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '${totalWastageWeight.toStringAsFixed(1)} kg',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: totalWastageWeight > 0 ? PdfColors.red700 : PdfColors.blue900,
                ),
              ),
      ],
          ),
        ],
      ),
    );
  }
  
  // ========== EXCEL BUILDERS ==========
  
  static void _addExcelHeader(excel.Sheet sheet) {
    final headerRow = [
      excel.TextCellValue('Product'),
      excel.TextCellValue('Stock Counted'),
      excel.TextCellValue('Weight (kg)'),
      excel.TextCellValue('Unit'),
      excel.TextCellValue('Comment'),
      excel.TextCellValue('Wastage Qty'),
      excel.TextCellValue('Wastage Weight (kg)'),
      excel.TextCellValue('Reason'),
      excel.TextCellValue('Errors/Issues'),  // Add Errors/Issues column
    ];
    sheet.appendRow(headerRow);
    
    // Style header row
    for (int i = 0; i < headerRow.length; i++) {
      final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.cellStyle = excel.CellStyle(
        bold: true,
        horizontalAlign: (i == 1 || i == 2 || i == 5 || i == 6) ? excel.HorizontalAlign.Right : excel.HorizontalAlign.Center, // Right-align numeric columns: Stock Counted (1), Weight (2), Wastage Qty (5), Wastage Weight (6)
      );
    }
  }
  
  static void _addExcelDataRow(
    excel.Sheet sheet,
    Map<String, dynamic> entry,
    List<Product> stockTakeProducts,
  ) {
    final productId = entry['product_id'] as int;
    final product = stockTakeProducts.where((p) => p.id == productId).firstOrNull;
    
    if (product == null) {
      print('[EXCEL] ERROR: Product with ID $productId not found');
      return;
    }
    
    final countedStock = entry['counted_quantity'] as double;
    final weight = entry['weight'] as double? ?? 0.0;
    final wastageQuantity = entry['wastage_quantity'] as double? ?? 0.0;
    final wastageWeight = entry['wastage_weight'] as double? ?? 0.0;
    final wastageReason = entry['wastage_reason'] as String? ?? '';
    final comment = entry['comment'] as String? ?? '';
    
    // Add indicator for unlimited stock products
    final productName = product.unlimitedStock 
        ? '🌱 ${product.name}'
        : product.name;
    
    // Format stock counted - show count only (not combined with weight)
    // For discrete units: show whole numbers
    // For continuous units: show decimals
    final productUnit = (product.unit ?? '').toLowerCase().trim();
    final stockCountedDisplay = (productUnit == 'kg' || productUnit == 'g' || productUnit == 'ml' || productUnit == 'l')
        ? (countedStock > 0 ? countedStock.toStringAsFixed(1) : '0.0')
        : (countedStock > 0 ? countedStock.toInt().toString() : '0');
    final stockCountedValue = excel.TextCellValue(stockCountedDisplay);
    final commentValue = comment.isNotEmpty 
        ? excel.TextCellValue(comment)
        : excel.TextCellValue('-');
    final weightValue = weight > 0 
        ? excel.TextCellValue(weight.toStringAsFixed(1))
        : excel.TextCellValue('-');
    
    final wastageQtyValue = wastageQuantity > 0 
        ? excel.TextCellValue(wastageQuantity % 1 == 0 
            ? wastageQuantity.toInt().toString() 
            : wastageQuantity.toStringAsFixed(1))
        : excel.TextCellValue('-');
    final wastageWeightValue = wastageWeight > 0 
        ? excel.TextCellValue(wastageWeight.toStringAsFixed(1))
        : excel.TextCellValue('-');
    
    // Extract error information
    String errorField = '';
    final List<String> errors = [];
    
    // Check for missing required data
    final isKgProduct = productUnit == 'kg';
    
    if (isKgProduct && weight <= 0) {
      errors.add('Missing Required Data: Weight is required for kg products');
    } else if (!isKgProduct && countedStock <= 0) {
      // For discrete units: count is required, weight is optional (for audit trail)
      errors.add('Missing Required Data: Quantity (count) is required for ${productUnit} products');
    }
    
    // Check for wastage without reason
    if ((wastageQuantity > 0 || wastageWeight > 0) && wastageReason.isEmpty) {
      errors.add('Wastage Recorded: Wastage quantity/weight entered but no reason provided');
    }
    
    // Check for product not found (shouldn't happen but just in case)
    if (productId <= 0) {
      errors.add('Invalid Product: Product ID is invalid');
    }
    
    errorField = errors.join('\n');
    
    final dataRow = [
      excel.TextCellValue(productName),
      stockCountedValue,
      weightValue,
      excel.TextCellValue(product.unit),
      commentValue,
      wastageQtyValue,
      wastageWeightValue,
      excel.TextCellValue(wastageReason.isNotEmpty ? wastageReason : '-'),
      excel.TextCellValue(errorField),  // Errors/Issues column
    ];
    
    sheet.appendRow(dataRow);
    
    // Right-align numeric columns: Stock Counted (1), Weight (2), Wastage Qty (5), Wastage Weight (6)
    final rowIndex = sheet.maxRows - 1;
    final stockCountedCell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
    stockCountedCell.cellStyle = excel.CellStyle(
      horizontalAlign: excel.HorizontalAlign.Right,
    );
    final weightCell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex));
    weightCell.cellStyle = excel.CellStyle(
      horizontalAlign: excel.HorizontalAlign.Right,
    );
    final wastageQtyCell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex));
    wastageQtyCell.cellStyle = excel.CellStyle(
      horizontalAlign: excel.HorizontalAlign.Right,
    );
    final wastageWeightCell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex));
    wastageWeightCell.cellStyle = excel.CellStyle(
      horizontalAlign: excel.HorizontalAlign.Right,
    );
  }

  /// Add Errors sheet - lists all entries with errors/issues
  static void _addErrorsSheet(excel.Excel excelFile, List<Map<String, dynamic>> entries, List<Product> stockTakeProducts) {
    print('[STOCK_TAKE_EXCEL] Building Errors sheet');
    
    // Filter entries with errors
    final entriesWithErrors = entries.where((entry) {
      final productId = entry['product_id'] as int;
      final product = stockTakeProducts.where((p) => p.id == productId).firstOrNull;
      
      if (product == null) return true;
      
      final productUnit = (product.unit ?? '').toLowerCase().trim();
      final isKgProduct = productUnit == 'kg';
      final countedStock = entry['counted_quantity'] as double? ?? 0.0;
      final weight = entry['weight'] as double? ?? 0.0;
      final wastageQuantity = entry['wastage_quantity'] as double? ?? 0.0;
      final wastageWeight = entry['wastage_weight'] as double? ?? 0.0;
      final wastageReason = entry['wastage_reason'] as String? ?? '';
      
      // Check for missing required data
      if (isKgProduct && weight <= 0) return true;
      if (!isKgProduct && countedStock <= 0) return true;  // Count is required for discrete units
      
      // Check for wastage without reason
      if ((wastageQuantity > 0 || wastageWeight > 0) && wastageReason.isEmpty) return true;
      
      return false;
    }).toList();
    
    // If no errors, skip creating the sheet
    if (entriesWithErrors.isEmpty) {
      print('[STOCK_TAKE_EXCEL] No entries with errors - skipping Errors sheet');
      return;
    }
    
    final sheet = excelFile['Errors'];
    
    // Sheet title
    sheet.cell(excel.CellIndex.indexByString('A1')).value = excel.TextCellValue('ITEMS WITH ERRORS/ISSUES');
    sheet.cell(excel.CellIndex.indexByString('A1')).cellStyle = excel.CellStyle(
      bold: true,
      fontSize: 16,
    );
    
    // Table headers
    int currentRow = 3;
    final headers = ['Product', 'Stock Counted', 'Weight (kg)', 'Unit', 'Error Type', 'Error Details', 'Action Required'];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = excel.TextCellValue(headers[i]);
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).cellStyle = excel.CellStyle(
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Center,
      );
    }
    currentRow++;
    
    // Add error entries
    for (final entry in entriesWithErrors) {
      final productId = entry['product_id'] as int;
      final product = stockTakeProducts.where((p) => p.id == productId).firstOrNull;
      
      if (product == null) {
        // Product not found error
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue('Product ID: $productId');
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = excel.TextCellValue('-');
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow)).value = excel.TextCellValue('-');
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).value = excel.TextCellValue('-');
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).value = excel.TextCellValue('Product Not Found');
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow)).value = excel.TextCellValue('Product with ID $productId was not found in the system');
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow)).value = excel.TextCellValue('Check product ID or remove entry');
        currentRow++;
        continue;
      }
      
      final productUnit = (product.unit ?? '').toLowerCase().trim();
      final isKgProduct = productUnit == 'kg';
      final countedStock = entry['counted_quantity'] as double? ?? 0.0;
      final weight = entry['weight'] as double? ?? 0.0;
      final wastageQuantity = entry['wastage_quantity'] as double? ?? 0.0;
      final wastageWeight = entry['wastage_weight'] as double? ?? 0.0;
      final wastageReason = entry['wastage_reason'] as String? ?? '';
      
      String errorType = 'Unknown';
      String errorDetails = '';
      String actionRequired = '';
      
      // Determine error type and details
      if (isKgProduct && weight <= 0) {
        errorType = 'Missing Required Data';
        errorDetails = 'Weight is required for kg products but was not provided.\n'
            'Current Weight: ${weight > 0 ? weight : 0} kg';
        actionRequired = 'Enter weight for this kg product';
      } else if (!isKgProduct && countedStock <= 0) {
        errorType = 'Missing Required Data';
        errorDetails = 'Quantity (count) is required for ${productUnit} products but was not provided.\n'
            'Current Counted: $countedStock\n'
            'Current Weight: ${weight > 0 ? weight : 0} kg (optional)';
        actionRequired = 'Enter quantity (count) for this ${productUnit} product';
      } else if ((wastageQuantity > 0 || wastageWeight > 0) && wastageReason.isEmpty) {
        errorType = 'Wastage Without Reason';
        errorDetails = 'Wastage was recorded but no reason was provided.\n'
            'Wastage Quantity: $wastageQuantity\n'
            'Wastage Weight: $wastageWeight kg';
        actionRequired = 'Add a reason for the wastage';
      }
      
      final rowData = [
        excel.TextCellValue(product.name),
        excel.DoubleCellValue(countedStock),
        weight > 0 ? excel.DoubleCellValue(weight) : excel.TextCellValue('-'),
        excel.TextCellValue(product.unit),
        excel.TextCellValue(errorType),
        excel.TextCellValue(errorDetails),
        excel.TextCellValue(actionRequired),
      ];
      
      for (int i = 0; i < rowData.length; i++) {
        final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
        cell.value = rowData[i];
      }
      currentRow++;
    }
    
    // Auto-fit columns
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnAutoFit(i);
    }
    
    print('[STOCK_TAKE_EXCEL] Errors sheet built successfully with ${entriesWithErrors.length} entries');
  }

}


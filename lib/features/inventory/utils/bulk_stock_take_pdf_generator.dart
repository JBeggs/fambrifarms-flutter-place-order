import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as excel;
import '../../../models/product.dart';

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
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            _buildPdfHeader(now),
            pw.SizedBox(height: 20),
            _buildPdfTableHeader(),
            ..._buildPdfTableRows(sortedEntries, stockTakeProducts),
            pw.SizedBox(height: 20),
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
      
      // Auto-fit columns
      for (int i = 0; i < 8; i++) {
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
    return pw.Header(
      level: 0,
      child: pw.Text(
        'Stock Report',
        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
      ),
    );
  }
  
  static pw.Widget _buildPdfTableHeader() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey300,
        border: pw.Border(bottom: pw.BorderSide(width: 2)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(flex: 3, child: pw.Text('Product', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Expanded(
            flex: 2, 
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Stock Counted', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
            ),
          ),
          pw.Expanded(flex: 1, child: pw.Text('Unit', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Expanded(flex: 2, child: pw.Text('Weight (kg)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Expanded(flex: 2, child: pw.Text('Comment', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Expanded(flex: 2, child: pw.Text('Wastage Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Expanded(flex: 2, child: pw.Text('Wastage Weight (kg)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Expanded(flex: 2, child: pw.Text('Reason', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        ],
      ),
    );
  }
  
  static List<pw.Widget> _buildPdfTableRows(
    List<Map<String, dynamic>> entries,
    List<Product> stockTakeProducts,
  ) {
    return entries.map((entry) {
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
      
      // Standard display - always show count in Stock Counted column
      final stockCountedDisplay = countedStock % 1 == 0 
          ? countedStock.toInt().toString() 
          : countedStock.toStringAsFixed(2);
      
      final commentDisplay = comment.isNotEmpty ? comment : '-';
      
      return pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey)),
        ),
        child: pw.Row(
          children: [
            // Product name
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                productName, 
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              ),
            ),
            // Stock Counted (kg) - always shows count (right-aligned)
            pw.Expanded(
              flex: 2,
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  stockCountedDisplay,
                  style: const pw.TextStyle(fontSize: 10),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ),
            // Unit
            pw.Expanded(
              flex: 1,
              child: pw.Text(product.unit, style: const pw.TextStyle(fontSize: 10)),
            ),
            // Weight (kg)
            pw.Expanded(
              flex: 2,
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  weight > 0 
                    ? (weight % 1 == 0 ? weight.toInt().toString() : weight.toStringAsFixed(2))
                    : '-',
                  style: const pw.TextStyle(fontSize: 10),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ),
            // Comment
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                commentDisplay,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ),
            // Wastage Quantity
            pw.Expanded(
              flex: 2,
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  wastageQuantity > 0 
                    ? (wastageQuantity % 1 == 0 ? wastageQuantity.toInt().toString() : wastageQuantity.toStringAsFixed(2))
                    : '-',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: wastageQuantity > 0 ? PdfColors.red : PdfColors.black,
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
                    ? (wastageWeight % 1 == 0 ? wastageWeight.toInt().toString() : wastageWeight.toStringAsFixed(2))
                    : '-',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: wastageWeight > 0 ? PdfColors.red : PdfColors.black,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ),
            // Wastage Reason
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                wastageReason.isNotEmpty ? wastageReason : '-',
                style: const pw.TextStyle(fontSize: 9),
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
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Total Products: ${entries.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text('Products with Wastage: $productsWithWastage', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ],
    );
  }
  
  // ========== EXCEL BUILDERS ==========
  
  static void _addExcelHeader(excel.Sheet sheet) {
    final headerRow = [
      excel.TextCellValue('Product'),
      excel.TextCellValue('Stock Counted'),
      excel.TextCellValue('Unit'),
      excel.TextCellValue('Weight (kg)'),
      excel.TextCellValue('Comment'),
      excel.TextCellValue('Wastage Qty'),
      excel.TextCellValue('Wastage Weight (kg)'),
      excel.TextCellValue('Reason'),
    ];
    sheet.appendRow(headerRow);
    
    // Style header row
    for (int i = 0; i < headerRow.length; i++) {
      final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.cellStyle = excel.CellStyle(
        bold: true,
        horizontalAlign: (i == 1 || i == 3 || i == 5 || i == 6) ? excel.HorizontalAlign.Right : excel.HorizontalAlign.Center, // Right-align numeric columns: Stock Counted (1), Weight (3), Wastage Qty (5), Wastage Weight (6)
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
    
    // Standard values - always show count in Stock Counted column
    final stockCountedValue = excel.DoubleCellValue(countedStock);
    final commentValue = comment.isNotEmpty 
        ? excel.TextCellValue(comment)
        : excel.TextCellValue('-');
    final weightValue = weight > 0 
        ? excel.DoubleCellValue(weight)
        : excel.TextCellValue('-');
    
    final wastageQtyValue = wastageQuantity > 0 
        ? excel.DoubleCellValue(wastageQuantity) 
        : excel.TextCellValue('-');
    final wastageWeightValue = wastageWeight > 0 
        ? excel.DoubleCellValue(wastageWeight) 
        : excel.TextCellValue('-');
    
    final dataRow = [
      excel.TextCellValue(productName),
      stockCountedValue,
      excel.TextCellValue(product.unit),
      weightValue,
      commentValue,
      wastageQtyValue,
      wastageWeightValue,
      excel.TextCellValue(wastageReason.isNotEmpty ? wastageReason : '-'),
    ];
    
    sheet.appendRow(dataRow);
    
    // Right-align numeric columns: Stock Counted (1), Weight (3), Wastage Qty (5), Wastage Weight (6)
    final rowIndex = sheet.maxRows - 1;
    final stockCountedCell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
    stockCountedCell.cellStyle = excel.CellStyle(
      horizontalAlign: excel.HorizontalAlign.Right,
    );
    final weightCell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex));
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
}


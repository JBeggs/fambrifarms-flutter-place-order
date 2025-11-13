import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:io';
import '../../../services/api_service.dart';
import '../../../services/pdf_service.dart';
import '../../../services/excel_service.dart';
import '../../../utils/messages_provider.dart';
import '../../../providers/products_provider.dart';
import '../../../models/product.dart' as product_model;

class AlwaysSuggestionsDialog extends ConsumerStatefulWidget {
  final String messageId;
  final Map<String, dynamic> suggestionsData;

  const AlwaysSuggestionsDialog({
    super.key,
    required this.messageId,
    required this.suggestionsData,
  });

  @override
  ConsumerState<AlwaysSuggestionsDialog> createState() => _AlwaysSuggestionsDialogState();
}

class _AlwaysSuggestionsDialogState extends ConsumerState<AlwaysSuggestionsDialog> {
  final Map<String, Map<String, dynamic>> _selectedSuggestions = {};
  final Map<String, double> _quantities = {};
  final Map<String, String> _units = {};
  final Map<String, String> _stockActions = {}; // 'reserve', 'no_reserve', 'convert_to_kg'
  final Map<String, TextEditingController> _unitControllers = {};
  final Map<String, bool> _skippedItems = {}; // Track items that should be skipped
  // Source product for stock deduction
  final Map<String, bool> _useSourceProduct = {}; // Track if source product is used per item
  final Map<String, Map<String, dynamic>> _selectedSourceProducts = {}; // Source product per item
  final Map<String, double> _sourceQuantities = {}; // Source quantity per item
  final Map<String, TextEditingController> _sourceQuantityControllers = {};
  // Track edited original text and loading state for search
  final Map<String, String> _editedOriginalText = {}; // Store edited search terms
  final Map<String, bool> _isEditingSearch = {}; // Track if user is currently editing search term
  final Map<String, bool> _isSearching = {}; // Track if search is in progress per item
  final Map<String, List<dynamic>> _updatedSuggestions = {}; // Store updated suggestions per item
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeSelections();
    _initializeEditedText();
  }

  // Initialize edited original text map with original values
  void _initializeEditedText() {
    for (var item in widget.suggestionsData['items']) {
      final originalText = item['original_text'] as String;
      _editedOriginalText[originalText] = originalText;
      // Initialize search controllers
      if (!_unitControllers.containsKey('${originalText}_search')) {
        _unitControllers['${originalText}_search'] = TextEditingController(text: originalText);
      }
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (var controller in _unitControllers.values) {
      controller.dispose();
    }
    for (var controller in _sourceQuantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _formatProductDisplay(Map<String, dynamic> suggestion) {
    final productName = suggestion['product_name'] ?? 'Unknown';
    final unit = suggestion['unit'];
    
    // If product name already contains packaging info (e.g., "Strawberries (200g)")
    if (productName.contains('(') && productName.contains(')')) {
      // Check if we should add unit information for better clarity
      if (unit != null && unit.toString().isNotEmpty) {
        final unitStr = unit.toString();
        // If the unit is different from just weight units, add it for clarity
        if (unitStr == 'punnet' || unitStr == 'box' || unitStr == 'bag' || 
            unitStr == 'bunch' || unitStr == 'head' || unitStr == 'each' || unitStr == 'packet') {
          // Extract the weight part and add unit type on next line
          final regex = RegExp(r'(.*)\s*\(([^)]+)\)(.*)');
          final match = regex.firstMatch(productName);
          if (match != null) {
            final baseName = match.group(1)?.trim() ?? '';
            final weightInfo = match.group(2) ?? '';
            final suffix = match.group(3) ?? '';
            return '$baseName$suffix\n($weightInfo $unitStr)';
          }
        }
      }
      // Extract base name and put packaging info on next line
      final regex = RegExp(r'(.*)\s*\(([^)]+)\)(.*)');
      final match = regex.firstMatch(productName);
      if (match != null) {
        final baseName = match.group(1)?.trim() ?? '';
        final packagingInfo = match.group(2) ?? '';
        final suffix = match.group(3) ?? '';
        return '$baseName$suffix\n($packagingInfo)';
      }
      return productName;
    }
    
    // Otherwise, append the unit on next line
    if (unit != null && unit.toString().isNotEmpty) {
      return '$productName\n($unit)';
    }
    
    return productName;
  }

  Widget _buildStockStatusBadge(Map<String, dynamic> suggestion) {
    final stock = suggestion['stock'] as Map<String, dynamic>?;
    
    if (stock == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'NO STOCK INFO',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      );
    }
    
    final available = (stock['available_quantity'] as num?)?.toDouble() ?? 0.0;
    final reserved = (stock['reserved_quantity'] as num?)?.toDouble() ?? 0.0;
    
    String statusText;
    Color bgColor;
    Color textColor;
    
    if (available > 0) {
      statusText = '${available.toStringAsFixed(1)} AVAIL';
      bgColor = Colors.green.withValues(alpha: 0.2);
      textColor = Colors.green.shade700;
      if (reserved > 0) {
        statusText += ' (${reserved.toStringAsFixed(1)} res)';
      }
    } else if (reserved > 0) {
      statusText = '${reserved.toStringAsFixed(1)} RES ONLY';
      bgColor = Colors.orange.withValues(alpha: 0.2);
      textColor = Colors.orange.shade700;
    } else {
      statusText = 'OUT OF STOCK';
      bgColor = Colors.red.withValues(alpha: 0.2);
      textColor = Colors.white; // White text for better contrast on red background
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  void _initializeSelections() {
    final items = widget.suggestionsData['items'] as List<dynamic>? ?? [];
    
    for (var item in items) {
      final originalText = item['original_text'] as String;
      final parsed = item['parsed'] as Map<String, dynamic>;
      final suggestions = item['suggestions'] as List<dynamic>? ?? [];
      
      // Don't auto-select here - we'll do it after sorting for better selection
      
      // Initialize quantities and units from parsed data
      _quantities[originalText] = (parsed['quantity'] as num?)?.toDouble() ?? 1.0;
      _units[originalText] = parsed['unit'] as String? ?? 'each';
      
      // Initialize TextEditingController for unit editing
      _unitControllers[originalText] = TextEditingController(text: _units[originalText]);
      
      // Initialize source product controllers
      _sourceQuantityControllers[originalText] = TextEditingController();
      
      // Auto-select the best suggestion based on stock availability and matching
      if (suggestions.isNotEmpty) {
        // Sort suggestions by: 1) In stock first, 2) Confidence score (product relevance is MOST important)
        final sortedSuggestions = List<Map<String, dynamic>>.from(suggestions);
        sortedSuggestions.sort((a, b) {
          // Priority 1: Confidence score (product relevance is MOST important)
          // NEVER let stock status override confidence for high-confidence matches!
          // Never let package size override confidence score - this was causing bananas to be selected over avocados!
          final aScore = (a['confidence_score'] as num?)?.toDouble() ?? 0.0;
          final bScore = (b['confidence_score'] as num?)?.toDouble() ?? 0.0;
          
          // Only use tiebreakers if confidence scores are EXACTLY the same
          if (aScore == bScore) {
            // Priority 3a: Exact product name matching (cherry vs cocktail)
            final originalLower = originalText.toLowerCase();
            final aProductName = (a['product_name'] as String? ?? '').toLowerCase();
            final bProductName = (b['product_name'] as String? ?? '').toLowerCase();
            
            // Check for exact word matches in product names
            final originalWords = originalLower.replaceAll(RegExp(r'\d+|\b(kg|g|ml|l|box|bag|bunch|head|each|packet|punnet)\b'), '').trim().split(RegExp(r'\s+'));
            
            int aWordMatches = 0;
            int bWordMatches = 0;
            
            for (final word in originalWords) {
              if (word.length > 2) { // Skip short words
                if (aProductName.contains(word)) aWordMatches++;
                if (bProductName.contains(word)) bWordMatches++;
              }
            }
            
            // Debug output for cherry tomatoes
            if (originalLower.contains('cherry')) {
              print('🍅 CHERRY TOMATOES TIEBREAKER DEBUG:');
              print('  Original: "$originalText"');
              print('  Original words: $originalWords');
              print('  A: "$aProductName" (matches: $aWordMatches)');
              print('  B: "$bProductName" (matches: $bWordMatches)');
            }
            
            if (aWordMatches != bWordMatches) {
              return bWordMatches.compareTo(aWordMatches); // More word matches first
            }
            
            // Priority 3b: Stock availability as secondary tiebreaker (only for same confidence)
            final aInStock = a['in_stock'] as bool? ?? false;
            final bInStock = b['in_stock'] as bool? ?? false;
            if (aInStock != bInStock) {
              return bInStock ? 1 : -1; // In stock items first, but only as tiebreaker
            }
            
            // Priority 3c: Package size matching as tertiary tiebreaker
            final packageSizePattern = RegExp(r'(\d+(?:\.\d+)?)\s*(kg|g|ml|l)', caseSensitive: false);
            final match = packageSizePattern.firstMatch(originalText);
            if (match != null) {
              final expectedSize = '${match.group(1)}${match.group(2)}';
              final aPackageSize = a['packaging_size'] as String? ?? '';
              final bPackageSize = b['packaging_size'] as String? ?? '';
              final aMatches = aPackageSize.toLowerCase().contains(expectedSize.toLowerCase());
              final bMatches = bPackageSize.toLowerCase().contains(expectedSize.toLowerCase());
              if (aMatches != bMatches) {
                return aMatches ? -1 : 1; // Matching package size as tiebreaker
              }
            }
          }
          
          return bScore.compareTo(aScore);
        });
        
        // First try to find a product with the matching unit
        final parsedUnit = _units[originalText];
        Map<String, dynamic>? unitMatch;
        
        for (var suggestion in sortedSuggestions) {
          if (suggestion['unit'].toString().toLowerCase() == parsedUnit?.toLowerCase()) {
            unitMatch = suggestion;
            break;
          }
        }
        
        _selectedSuggestions[originalText] = unitMatch ?? sortedSuggestions.first;
        
        // CRITICAL FIX: Update unit to match the auto-selected product
        final autoSelected = _selectedSuggestions[originalText];
        if (autoSelected != null) {
          final productUnit = autoSelected['unit'] as String? ?? 'each';
          _units[originalText] = productUnit;
          _unitControllers[originalText]?.text = productUnit;
        }
      } else if (suggestions.isNotEmpty) {
        // Fallback: if no suggestions after sorting, use the first original suggestion
        _selectedSuggestions[originalText] = suggestions.first;
        
        // CRITICAL FIX: Update unit to match the auto-selected product
        final autoSelected = _selectedSuggestions[originalText];
        if (autoSelected != null) {
          final productUnit = autoSelected['unit'] as String? ?? 'each';
          _units[originalText] = productUnit;
          _unitControllers[originalText]?.text = productUnit;
        }
      }
      
      // Initialize stock action - default based on stock availability and product type
      final selectedSuggestion = _selectedSuggestions[originalText];
      if (selectedSuggestion != null) {
        final productName = selectedSuggestion['product_name'] as String? ?? '';
        final unit = selectedSuggestion['unit'] as String? ?? '';
        final inStock = selectedSuggestion['in_stock'] as bool? ?? false;
        final unlimitedStock = selectedSuggestion['unlimited_stock'] as bool? ?? false;
        
        // Always set to 'no_reserve' for unlimited stock products (garden-grown)
        if (unlimitedStock) {
          _stockActions[originalText] = 'no_reserve';
        }
        // Default to 'reserve' if item is in stock, 'no_reserve' if not in stock
        else if (inStock) {
          _stockActions[originalText] = 'reserve';
        } else if (unit == 'kg' && (productName.toLowerCase().contains('bulk') || productName.toLowerCase().contains('flexible'))) {
          _stockActions[originalText] = 'no_reserve';
        } else {
          _stockActions[originalText] = 'no_reserve'; // Don't reserve out-of-stock items by default
        }
      } else {
        _stockActions[originalText] = 'reserve';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawItems = widget.suggestionsData['items'] as List<dynamic>? ?? [];
    
    // Keep items in original message order (DO NOT SORT)
    final items = List<dynamic>.from(rawItems);
    
    final customer = widget.suggestionsData['customer'] as Map<String, dynamic>? ?? {};
    
    // Calculate the actual number of items that will be included (non-skipped)
    int includedItemsCount = 0;
    int completedItemsCount = 0;
    for (var item in items) {
      final originalText = item['original_text'] as String;
      final isSkipped = _skippedItems[originalText] ?? false;
      if (!isSkipped) {
        includedItemsCount++;
        // Check if item is completed (has selected suggestion)
        if (_selectedSuggestions.containsKey(originalText) && 
            _selectedSuggestions[originalText] != null) {
          completedItemsCount++;
        }
      }
    }
    
    // Check if all items are completed
    final allItemsCompleted = includedItemsCount > 0 && completedItemsCount == includedItemsCount;

    // Check if we're in a Scaffold (mobile full-screen) or Dialog (desktop)
    final isInScaffold = Scaffold.maybeOf(context) != null;

    // Content that's shared between both modes
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header (only show if NOT in Scaffold - Scaffold has AppBar)
        if (!isInScaffold) ...[
          Row(
            children: [
              const Icon(Icons.shopping_cart, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Confirm Order Items',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ],
            
            // Customer info
            if (customer.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Customer: ${customer['name'] ?? 'Unknown'}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Items list with confirm button at the end
            Expanded(
              child: ListView.builder(
                itemCount: items.length + (allItemsCompleted ? 1 : 0), // Add 1 for button if all completed
                itemBuilder: (context, index) {
                  // If this is the last item and all items are completed, show confirm button
                  if (allItemsCompleted && index == items.length) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          children: [
                            // Progress indicator showing completion
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'All items completed ($completedItemsCount/$includedItemsCount)',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Preview button - shows Excel preview
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: _isProcessing ? null : _previewOrderExcel,
                                icon: const Icon(Icons.preview, size: 20),
                                label: const Text(
                                  'Preview Excel',
                                  style: TextStyle(fontSize: 16),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Theme.of(context).primaryColor),
                                  foregroundColor: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Confirm Order button - bigger and prominent
                            SizedBox(
                              width: double.infinity,
                              height: 56, // Bigger button
                              child: ElevatedButton(
                                onPressed: _isProcessing ? null : _confirmOrder,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isProcessing 
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.check_circle, size: 24),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Confirm Order ($includedItemsCount items)',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Cancel button - smaller, less prominent
                            TextButton(
                              onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  // Regular item card
                  final item = items[index];
                  return _buildItemCard(item, index);
                },
              ),
            ),
            
            // Show progress indicator at bottom when not all items completed (non-scrollable footer)
            if (!allItemsCompleted)
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Complete all items to confirm order ($completedItemsCount/$includedItemsCount)',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
    );

    // Return content wrapped in Dialog for desktop, or directly for mobile Scaffold
    if (isInScaffold) {
      // Mobile: return content directly (already in Scaffold with AppBar)
      return Padding(
        padding: const EdgeInsets.all(16),
        child: content,
      );
    } else {
      // Desktop: wrap in Dialog
      return Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: content,
        ),
      );
    }
  }

  // Get suggestions for an item (either updated or original)
  List<dynamic> _getSuggestionsForItem(String originalText) {
    // If we have updated suggestions for this item, use those
    if (_updatedSuggestions.containsKey(originalText)) {
      return _updatedSuggestions[originalText]!;
    }
    // Otherwise, find the original item and return its suggestions
    for (var item in widget.suggestionsData['items']) {
      if (item['original_text'] == originalText) {
        return item['suggestions'] as List<dynamic>? ?? [];
      }
    }
    return [];
  }

  Widget _buildItemCard(Map<String, dynamic> item, int index) {
    final originalText = item['original_text'] as String;
    final suggestions = _getSuggestionsForItem(originalText);
    final isParsingFailure = item['is_parsing_failure'] as bool? ?? false;
    final isAmbiguousPackaging = item['is_ambiguous_packaging'] as bool? ?? false;
    final isSkipped = _skippedItems[originalText] ?? false;
    
    final quantity = _quantities[originalText] ?? 1.0;
    final unit = _units[originalText] ?? 'each';
    
    // Get the selected suggestion to show edited version in CORRECT FORMAT
    final selectedSuggestion = _selectedSuggestions[originalText];
    final formattedQuantity = quantity == quantity.toInt() 
        ? quantity.toInt().toString() 
        : quantity.toString();
    final editedText = selectedSuggestion != null 
        ? '$formattedQuantity ${selectedSuggestion['product_name']} $unit'
        : originalText;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSkipped ? Colors.grey.withValues(alpha: 0.2) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item number, checkbox, and original text
            Row(
              children: [
                // Checkbox to skip item
                Transform.scale(
                  scale: 0.8,
                  child: Checkbox(
                    value: !isSkipped, // Checked = include, unchecked = skip
                    onChanged: (value) {
                      setState(() {
                        _skippedItems[originalText] = !(value ?? true);
                      });
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSkipped 
                        ? Colors.grey.withValues(alpha: 0.3)
                        : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSkipped 
                          ? Colors.grey 
                          : Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildEditableSearchTerm(originalText, item),
                ),
                if (isParsingFailure)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Error',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else if (isAmbiguousPackaging)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Ambiguous',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            
            // Show original vs edited comparison
            if (selectedSuggestion != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Original: $originalText',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Edited: $editedText',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 8),
            
            // Compact quantity and unit editing
            Row(
              children: [
                const Text('Qty:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                const SizedBox(width: 4),
                SizedBox(
                  width: 60,
                  height: 28,
                  child: TextFormField(
                    key: ValueKey('${originalText}_quantity'), // Stable key for quantity field
                    initialValue: quantity == quantity.toInt() 
                        ? quantity.toInt().toString() 
                        : quantity.toString(),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 11),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    ),
                    onChanged: (value) {
                      final newQuantity = double.tryParse(value) ?? 1.0;
                      setState(() {
                        _quantities[originalText] = newQuantity;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Unit:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                const SizedBox(width: 4),
                SizedBox(
                  width: 70,
                  height: 28,
                  child: TextFormField(
                    key: ValueKey('${originalText}_unit'), // Stable key for unit field
                    controller: _unitControllers[originalText]!,
                    style: const TextStyle(fontSize: 11),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _units[originalText] = value;
                        
                        // Find product with matching unit
                        final currentSuggestion = _selectedSuggestions[originalText];
                        if (currentSuggestion != null && value.trim().isNotEmpty) {
                          final suggestions = widget.suggestionsData['items']
                              .firstWhere((item) => item['original_text'] == originalText)['suggestions'] as List<dynamic>;
                          
                          // Look for exact unit match
                          for (var suggestion in suggestions) {
                            if (suggestion['unit'].toLowerCase() == value.toLowerCase()) {
                              _selectedSuggestions[originalText] = suggestion;
                              break;
                            }
                          }
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Stock Action Selection
            _buildStockActionSelector(originalText, selectedSuggestion),
            
            const SizedBox(height: 8),
            
            // Source Product Selection
            _buildSourceProductSelector(originalText, selectedSuggestion),
            
            const SizedBox(height: 8),
            
            // Suggestions
            Text(
              'Select Product:',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            
            const SizedBox(height: 6),
            
            if (suggestions.isEmpty)
              (_isSearching[originalText] == true)
                  ? const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Searching...',
                          style: TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                      ],
                    )
                  : const Text(
                      'No suggestions available',
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    )
            else
              _buildSuggestionsList(suggestions, originalText),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsList(List<dynamic> suggestions, String originalText) {
    return Column(
      children: [
        // Selected suggestion - prominent display (shows the actually selected item)
        if (suggestions.isNotEmpty) ...[
          _buildProminentSuggestion(_selectedSuggestions[originalText] ?? suggestions.first, originalText, 0),
          if (suggestions.length > 1) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'All Options:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
        // All suggestions - compact display (including selected one so user can switch)
        if (suggestions.length > 1)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map<Widget>((suggestion) {
              return _buildCompactSuggestion(suggestion, originalText);
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildProminentSuggestion(Map<String, dynamic> suggestion, String originalText, int index) {
    final isSelected = _selectedSuggestions[originalText]?['product_id'] == suggestion['product_id'];
    final useSource = _useSourceProduct[originalText] ?? false;
    final suggestionProductId = suggestion['product_id'] as int?;
    final selectedSourceProduct = _selectedSourceProducts[originalText];
    final isSourceSelected = useSource && selectedSourceProduct != null && selectedSourceProduct['id'] == suggestionProductId;
    
    // Check if product has stock
    final stock = suggestion['stock'] as Map<String, dynamic>?;
    final availableQuantity = (stock?['available_quantity'] as num?)?.toDouble() ?? 0.0;
    final hasStock = availableQuantity > 0;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          if (useSource) {
            // Source product selection mode - only allow products with stock
            if (hasStock && suggestionProductId != _selectedSuggestions[originalText]?['product_id']) {
              _selectedSourceProducts[originalText] = {
                'id': suggestionProductId,
                'name': suggestion['product_name'] ?? '',
                'unit': suggestion['unit'] ?? '',
                'stockLevel': availableQuantity,
              };
            }
          } else {
            // Normal product selection
            _selectedSuggestions[originalText] = suggestion;
            // Update unit to match the selected suggestion
            _units[originalText] = suggestion['unit'] as String? ?? 'each';
            // Update the unit controller to reflect the change
            _unitControllers[originalText]?.text = suggestion['unit'] as String? ?? 'each';
          }
        });
      },
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 220,
          maxWidth: 400, // Increased width for longer product names
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: useSource && isSourceSelected
              ? Colors.amber.withValues(alpha: 0.3)
              : useSource && !hasStock
                  ? Colors.grey.withValues(alpha: 0.1)
                  : isSelected 
                      ? Colors.green.withValues(alpha: 0.25)
                      : Colors.blue.withValues(alpha: 0.1),
          border: Border.all(
            color: useSource && isSourceSelected
                ? Colors.amber.shade700
                : useSource && !hasStock
                    ? Colors.grey.withValues(alpha: 0.3)
                    : isSelected 
                        ? Colors.green.shade600
                        : Colors.blue.withValues(alpha: 0.3),
            width: (useSource && isSourceSelected) || isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: (useSource && isSourceSelected) || isSelected ? [
            BoxShadow(
              color: useSource && isSourceSelected
                  ? Colors.amber.withValues(alpha: 0.4)
                  : Colors.green.withValues(alpha: 0.4),
              blurRadius: 6,
              spreadRadius: 2,
            ),
          ] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: useSource && isSourceSelected
                        ? Colors.amber
                        : useSource && !hasStock
                            ? Colors.grey
                            : isSelected 
                                ? Colors.green 
                                : Colors.blue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    useSource && isSourceSelected
                        ? 'SOURCE'
                        : useSource && !hasStock
                            ? 'NO STOCK'
                            : isSelected 
                                ? 'SELECTED' 
                                : 'RECOMMENDED',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion['product_name'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.grey[100],
                          height: 1.1,
                        ),
                        maxLines: 3, // Increased to 3 lines for longer product names
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (suggestion['unit'] != null && suggestion['unit'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '(${suggestion['unit']})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isSelected ? Colors.white.withValues(alpha: 0.8) : Colors.grey[400],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'R${(suggestion['price'] ?? 0.0).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green[300],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${(suggestion['confidence_score'] ?? 0.0).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue[300],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (useSource && isSourceSelected) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.inventory_2,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ] else if (isSelected) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            // Add prominent stock status badge
            _buildStockStatusBadge(suggestion),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSuggestion(Map<String, dynamic> suggestion, String originalText) {
    final isSelected = _selectedSuggestions[originalText]?['product_id'] == suggestion['product_id'];
    final useSource = _useSourceProduct[originalText] ?? false;
    final suggestionProductId = suggestion['product_id'] as int?;
    final selectedSourceProduct = _selectedSourceProducts[originalText];
    final isSourceSelected = useSource && selectedSourceProduct != null && selectedSourceProduct['id'] == suggestionProductId;
    
    // Check if product has stock
    final stock = suggestion['stock'] as Map<String, dynamic>?;
    final availableQuantity = (stock?['available_quantity'] as num?)?.toDouble() ?? 0.0;
    final hasStock = availableQuantity > 0;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          if (useSource) {
            // Source product selection mode - only allow products with stock
            if (hasStock && suggestionProductId != _selectedSuggestions[originalText]?['product_id']) {
              _selectedSourceProducts[originalText] = {
                'id': suggestionProductId,
                'name': suggestion['product_name'] ?? '',
                'unit': suggestion['unit'] ?? '',
                'stockLevel': availableQuantity,
              };
            }
          } else {
            // Normal product selection
            _selectedSuggestions[originalText] = suggestion;
            // Update unit to match the selected suggestion
            _units[originalText] = suggestion['unit'] as String? ?? 'each';
            // Update the unit controller to reflect the change
            _unitControllers[originalText]?.text = suggestion['unit'] as String? ?? 'each';
          }
        });
      },
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 140,
          maxWidth: 250, // Increased from 180 to 250 for longer product names
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: useSource && isSourceSelected
              ? Colors.amber.shade600
              : useSource && !hasStock
                  ? Colors.grey.withValues(alpha: 0.1)
                  : isSelected 
                      ? Colors.green.shade600
                      : Colors.grey.withValues(alpha: 0.1),
          border: Border.all(
            color: useSource && isSourceSelected
                ? Colors.amber.shade300
                : useSource && !hasStock
                    ? Colors.grey.withValues(alpha: 0.3)
                    : isSelected 
                        ? Colors.green.shade300
                        : Colors.grey.withValues(alpha: 0.3),
            width: (useSource && isSourceSelected) || isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: (useSource && isSourceSelected) || isSelected ? [
            BoxShadow(
              color: useSource && isSourceSelected
                  ? Colors.amber.withValues(alpha: 0.6)
                  : Colors.green.withValues(alpha: 0.6),
              blurRadius: 6,
              spreadRadius: 2,
            ),
          ] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion['product_name'] ?? 'Unknown',
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey[100],
                    fontSize: 13,
                    height: 1.1,
                  ),
                  maxLines: 3, // Increased to 3 lines for longer product names
                  overflow: TextOverflow.ellipsis,
                ),
                if (suggestion['unit'] != null && suggestion['unit'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '(${suggestion['unit']})',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: isSelected ? Colors.white.withValues(alpha: 0.7) : Colors.grey[400],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'R${(suggestion['price'] ?? 0.0).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? Colors.green[300] : Colors.grey[300],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // Add stock status badge for compact suggestions too
            _buildStockStatusBadge(suggestion),
          ],
        ),
      ),
    );
  }

  Future<void> _previewOrderExcel() async {
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
                Text('Generating Excel preview...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Collect all selected items (excluding skipped items)
      final List<Map<String, dynamic>> orderItems = [];
      
      for (var item in widget.suggestionsData['items']) {
        final originalText = item['original_text'] as String;
        final isSkipped = _skippedItems[originalText] ?? false;
        
        // Skip items marked as skipped
        if (isSkipped) {
          continue;
        }
        
        final selectedSuggestion = _selectedSuggestions[originalText];
        final quantity = _quantities[originalText] ?? 1.0;
        final unit = _units[originalText] ?? 'each';
        
        if (selectedSuggestion != null) {
          final stockAction = _stockActions[originalText] ?? 'reserve';
          final itemData = {
            'product_name': selectedSuggestion['product_name'] ?? 'Unknown',
            'quantity': quantity,
            'unit': unit,
            'price': selectedSuggestion['price'] ?? 0.0,
            'original_text': originalText,
            'stock_action': stockAction,
            'in_stock': selectedSuggestion['in_stock'] ?? false,
            'unlimited_stock': selectedSuggestion['unlimited_stock'] ?? false,
          };
          
          // Add source product info if using source product
          if (_useSourceProduct[originalText] == true) {
            final sourceProduct = _selectedSourceProducts[originalText];
            final sourceQuantity = _sourceQuantities[originalText];
            if (sourceProduct != null) {
              itemData['source_product_name'] = sourceProduct['name'] ?? 'Unknown';
              itemData['source_quantity'] = sourceQuantity ?? 0.0;
            }
          }
          
          orderItems.add(itemData);
        }
      }
      
      if (orderItems.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No items to preview. Please select at least one item.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Generate Excel file
      final excel = Excel.createExcel();
      final sheet = excel['Order Preview'];
      
      // Remove default sheet
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }
      
      int currentRow = 0;
      
      // Header
      final customer = widget.suggestionsData['customer'];
      final customerName = customer != null ? (customer['name'] ?? 'Unknown') : 'Unknown';
      final timestamp = DateTime.now().toString().split('.')[0];
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('Order Preview');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = CellStyle(
        bold: true,
        fontSize: 16,
      );
      currentRow++;
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('Customer: $customerName');
      currentRow++;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('Generated: $timestamp');
      currentRow += 2;
      
      // Column headers
      final headers = ['Product Name', 'Quantity', 'Unit', 'Price', 'Stock Status', 'Original Text', 'Notes'];
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
        );
      }
      currentRow++;
      
      // Order Items
      for (final item in orderItems) {
        String stockStatus = 'Unknown';
        if (item['unlimited_stock'] == true) {
          stockStatus = '🌱 Always Available';
        } else if (item['stock_action'] == 'reserve') {
          stockStatus = item['in_stock'] == true ? '✅ Reserved' : '⚠️ Out of Stock';
        } else if (item['stock_action'] == 'no_reserve') {
          stockStatus = 'To Order';
        }
        
        String notes = '';
        if (item['source_product_name'] != null) {
          notes = 'Stock from: ${item['source_product_name']} (${item['source_quantity']})';
        }
        
        final rowData = [
          TextCellValue(item['product_name']),
          DoubleCellValue(item['quantity']),
          TextCellValue(item['unit']),
          DoubleCellValue(item['price']),
          TextCellValue(stockStatus),
          TextCellValue(item['original_text']),
          TextCellValue(notes),
        ];
        
        for (int i = 0; i < rowData.length; i++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = rowData[i];
        }
        currentRow++;
      }
      
      // Auto-fit columns
      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnAutoFit(i);
      }
      
      // Save Excel file
      final excelBytes = excel.save();
      
      if (excelBytes != null) {
        // Get temp directory
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filename = 'order_preview_$timestamp.xlsx';
        final filePath = '${tempDir.path}/$filename';
        final file = File(filePath);
        await file.writeAsBytes(excelBytes);
        
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
        
        // Share the file
        await Share.shareXFiles(
          [XFile(filePath, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
          subject: 'Order Preview - $customerName',
          text: 'Preview of order items before confirmation',
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Excel preview ready to share'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Failed to generate Excel bytes');
      }
    } catch (e) {
      print('[PREVIEW_EXCEL] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating preview: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _confirmOrder() async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      // Collect all selected items with their details (excluding skipped items)
      final List<Map<String, dynamic>> orderItems = [];
      
      for (var item in widget.suggestionsData['items']) {
        final originalText = item['original_text'] as String;
        final isSkipped = _skippedItems[originalText] ?? false;
        
        // Skip items marked as skipped
        if (isSkipped) {
          continue;
        }
        
        final selectedSuggestion = _selectedSuggestions[originalText];
        final quantity = _quantities[originalText] ?? 1.0;
        final unit = _units[originalText] ?? 'each';
        
        if (selectedSuggestion != null) {
          final stockAction = _stockActions[originalText] ?? 'reserve';
          final itemData = {
            'product_id': selectedSuggestion['product_id'],
            'product_name': selectedSuggestion['product_name'],
            'quantity': quantity,
            'unit': unit,
            'price': selectedSuggestion['price'],
            'original_text': originalText,
            'stock_action': stockAction,
          };
          
          // Add source product data if using source product
          if (_useSourceProduct[originalText] == true) {
            final sourceProduct = _selectedSourceProducts[originalText];
            final sourceQuantity = _sourceQuantities[originalText];
            
            // STRICT VALIDATION: Source product and quantity are REQUIRED
            if (sourceProduct == null) {
              if (mounted) {
                setState(() {
                  _isProcessing = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please select a source product for "${selectedSuggestion['product_name']}"'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
              return;
            }
            
            if (sourceQuantity == null || sourceQuantity <= 0) {
              if (mounted) {
                setState(() {
                  _isProcessing = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter quantity to deduct for source product "${sourceProduct['name']}"'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
              return;
            }
            
            itemData['source_product_id'] = sourceProduct['id'];
            itemData['source_quantity'] = sourceQuantity;
          }
          
          orderItems.add(itemData);
        }
      }
      
      if (orderItems.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select at least one item'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Create the order via API
      final apiService = ApiService();
      final result = await apiService.createOrderFromSuggestions(
        messageId: widget.messageId,
        customer: widget.suggestionsData['customer'],
        items: orderItems,
      );
      
      if (mounted) {
        if (result['status'] == 'success') {
          // Get the created order ID for PDF and Excel generation
          final orderId = result['order_id'];
          String filesMessage = '';
          
          // Generate PDF and Excel automatically if order ID is available
          if (orderId != null) {
            String? pdfPath;
            String? excelPath;
            
            try {
              pdfPath = await _generateOrderPdf(orderId);
            } catch (e) {
              print('[ORDER PDF] Error generating PDF: $e');
              // Don't fail the order creation if PDF generation fails
            }
            
            try {
              excelPath = await _generateOrderExcel(orderId);
            } catch (e) {
              print('[ORDER EXCEL] Error generating Excel: $e');
              // Don't fail the order creation if Excel generation fails
            }
            
            filesMessage = _buildFilesMessage(pdfPath, excelPath);
            
            // Share the generated files on Android
            if (pdfPath != null || excelPath != null) {
              try {
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
                    subject: 'Order ${result['order_number'] ?? orderId} - ${widget.suggestionsData['customer']?['name'] ?? 'Customer'}',
                    text: 'Order created successfully!',
                  );
                  print('[ORDER SHARE] Files shared successfully');
                }
              } catch (e) {
                print('[ORDER SHARE] Error sharing files: $e');
                // Don't fail if sharing fails - user can still manually share
              }
            }
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order created successfully!${result['message'] ?? ''}$filesMessage'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
          
          // Close dialog and refresh messages
          Navigator.of(context).pop();
          
          // Refresh the messages list to show the new order
          final messagesNotifier = ref.read(messagesProvider.notifier);
          await messagesNotifier.loadMessages();
          
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create order: ${result['message'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating order: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// Generate PDF for the created order
  Future<String?> _generateOrderPdf(int orderId) async {
    try {
      print('[ORDER PDF] Fetching order data for ID: $orderId');
      
      // Fetch the complete order data from API
      final apiService = ApiService();
      final order = await apiService.getOrder(orderId);
      
      print('[ORDER PDF] Order fetched: ${order.orderNumber}');
      
      // Generate PDF using the PDF service
      final pdfPath = await PdfService.generateOrderPdf(order);
      
      if (pdfPath != null) {
        print('[ORDER PDF] PDF generated successfully: $pdfPath');
        return pdfPath;
      } else {
        print('[ORDER PDF] PDF generation returned null');
        return null;
      }
    } catch (e) {
      print('[ORDER PDF] Error generating PDF: $e');
      return null;
    }
  }

  /// Generate Excel for the created order
  Future<String?> _generateOrderExcel(int orderId) async {
    try {
      print('[ORDER EXCEL] Fetching order data for ID: $orderId');
      
      // Fetch the complete order data from API
      final apiService = ApiService();
      final order = await apiService.getOrder(orderId);
      
      print('[ORDER EXCEL] Order fetched: ${order.orderNumber}');
      
      // Get products data for Excel sheets
      final productsState = ref.read(productsProvider);
      
      // Generate Excel using the Excel service
      final excelPath = await ExcelService.generateOrderExcel(order, products: productsState.products);
      
      if (excelPath != null) {
        print('[ORDER EXCEL] Excel generated successfully: $excelPath');
        return excelPath;
      } else {
        print('[ORDER EXCEL] Excel generation returned null');
        return null;
      }
    } catch (e) {
      print('[ORDER EXCEL] Error generating Excel: $e');
      return null;
    }
  }

  /// Build message for file generation results
  String _buildFilesMessage(String? pdfPath, String? excelPath) {
    if (pdfPath != null && excelPath != null) {
      final pdfFileName = pdfPath.split('/').last;
      final excelFileName = excelPath.split('/').last;
      return ' PDF saved: $pdfFileName, Excel saved: $excelFileName';
    } else if (pdfPath != null) {
      final pdfFileName = pdfPath.split('/').last;
      return ' PDF saved: $pdfFileName (Excel generation failed)';
    } else if (excelPath != null) {
      final excelFileName = excelPath.split('/').last;
      return ' Excel saved: $excelFileName (PDF generation failed)';
    } else {
      return ' (File generation failed - check console)';
    }
  }

  Widget _buildStockActionSelector(String originalText, Map<String, dynamic>? selectedSuggestion) {
    final currentAction = _stockActions[originalText] ?? 'reserve';
    final productName = selectedSuggestion?['product_name'] as String? ?? '';
    final unit = selectedSuggestion?['unit'] as String? ?? '';
    final stock = selectedSuggestion?['stock'] as Map<String, dynamic>?;
    final availableQuantity = (stock?['available_quantity'] as num?)?.toDouble() ?? 0.0;
    final inStock = selectedSuggestion?['in_stock'] as bool? ?? false;
    final unlimitedStock = selectedSuggestion?['unlimited_stock'] as bool? ?? false;
    
    // Show special message for unlimited stock products (garden-grown)
    if (unlimitedStock) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.eco, size: 16, color: Colors.green.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Always available (garden-grown) - no reservation needed',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.green.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // Don't show stock actions if there's no available stock (reserved stock counts as unavailable)
    final reserved = (stock?['reserved_quantity'] as num?)?.toDouble() ?? 0.0;
    final hasAvailableStock = availableQuantity > 0; // Only free stock counts as available
    
    if (!hasAvailableStock) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, size: 16, color: Colors.red.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                reserved > 0 
                  ? 'Stock reserved for other orders - will be placed without reservation'
                  : 'No stock available - order will be placed without reservation',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // Check if this product supports flexible kg conversion
    // Show conversion option when:
    // 1. Product supports conversion (has kg or packaged variants available)
    // 2. Current selection has insufficient stock (need to convert from other formats)
    // 3. Allow bidirectional conversion: kg ↔ packets/boxes/bags/punnets
    final supportsConversion = unit == 'kg' || unit == 'packet' || unit == 'box' || 
      unit == 'bag' || unit == 'punnet' || unit == 'each' ||
      productName.toLowerCase().contains('box') || 
      productName.toLowerCase().contains('bag') ||
      productName.toLowerCase().contains('punnet') ||
      productName.toLowerCase().contains('packet');
    
    final canConvertToBulk = supportsConversion && availableQuantity <= 0;
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stock Action:',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          
          // Stock action options
          Wrap(
            spacing: 8,
            children: [
              // Reserve stock option
              _buildStockActionChip(
                originalText,
                'reserve',
                'Reserve Stock',
                Icons.lock,
                Colors.green,
                currentAction == 'reserve',
              ),
              
              // No reserve option
              _buildStockActionChip(
                originalText,
                'no_reserve',
                'No Reserve',
                Icons.lock_open,
                Colors.orange,
                currentAction == 'no_reserve',
              ),
              
              // Flexible kg conversion option (only if applicable)
              if (canConvertToBulk)
                _buildStockActionChip(
                  originalText,
                  'convert_to_kg',
                  'Flexible Kg Conversion',
                  Icons.transform,
                  Colors.blue,
                  currentAction == 'convert_to_kg',
                ),
            ],
          ),
          
          // Show stock availability info
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: inStock ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Available: ${availableQuantity.toStringAsFixed(1)} $unit',
              style: TextStyle(
                fontSize: 10,
                color: inStock ? Colors.green.shade700 : Colors.orange.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          // Show explanation based on selected action
          const SizedBox(height: 4),
          Text(
            _getStockActionExplanation(currentAction, canConvertToBulk),
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceProductSelector(String originalText, Map<String, dynamic>? selectedSuggestion) {
    if (selectedSuggestion == null) return const SizedBox.shrink();
    
    final productId = selectedSuggestion['product_id'] as int?;
    final useSource = _useSourceProduct[originalText] ?? false;
    final selectedSourceProduct = _selectedSourceProducts[originalText];
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: useSource,
                onChanged: (value) {
                  setState(() {
                    _useSourceProduct[originalText] = value ?? false;
                    if (!value!) {
                      _selectedSourceProducts.remove(originalText);
                      _sourceQuantities.remove(originalText);
                      _sourceQuantityControllers[originalText]?.clear();
                    }
                  });
                },
              ),
              Expanded(
                child: Text(
                  'Use stock from another product',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          
          if (useSource) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.blue.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      selectedSourceProduct != null
                        ? 'Source: ${selectedSourceProduct['name']} (${selectedSourceProduct['stockLevel']} ${selectedSourceProduct['unit']})'
                        : 'Click on any product below with stock to use as source',
                      style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
            
            // Always show quantity field when source is enabled
            const SizedBox(height: 8),
            TextField(
              controller: _sourceQuantityControllers[originalText],
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                labelText: selectedSourceProduct != null
                    ? 'Quantity to Deduct (${selectedSourceProduct['unit'] ?? ''}) *'
                    : 'Quantity to Deduct *',
                labelStyle: TextStyle(fontSize: 11),
                suffixText: selectedSourceProduct?['unit'] as String? ?? '',
                hintText: selectedSourceProduct != null ? 'e.g., 5' : 'Select source product first',
                helperText: selectedSourceProduct != null
                    ? 'Required: Enter amount to deduct from ${selectedSourceProduct['name']}'
                    : 'Select a source product above first, then enter quantity',
                helperMaxLines: 2,
              ),
              style: TextStyle(fontSize: 11),
              onChanged: (value) {
                final quantity = double.tryParse(value);
                if (quantity != null && quantity > 0) {
                  _sourceQuantities[originalText] = quantity;
                } else {
                  _sourceQuantities.remove(originalText);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStockActionChip(
    String originalText,
    String action,
    String label,
    IconData icon,
    Color color,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _stockActions[originalText] = action;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.4),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: isSelected ? color : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? color : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStockActionExplanation(String action, bool canConvertToBulk) {
    switch (action) {
      case 'reserve':
        return 'Stock will be reserved immediately when order is created';
      case 'no_reserve':
        return 'Stock will NOT be reserved - items remain available for other orders';
      case 'convert_to_kg':
        return canConvertToBulk 
          ? 'Flexible conversion: Use available stock from other formats (kg ↔ packets/boxes/bags) to fulfill this order'
          : 'Conversion not available for this item type';
      default:
        return '';
    }
  }

  /// Calculate appropriate kg quantity based on product packaging information
  double? _calculateKgQuantity(Map<String, dynamic> suggestion, double currentQuantity) {
    final productName = suggestion['product_name'] as String? ?? '';
    final originalUnit = suggestion['unit'] as String? ?? '';
    
    // Don't change if already in kg
    if (originalUnit.toLowerCase() == 'kg') {
      return null;
    }
    
    // Try to extract weight from product name (e.g., "Potatoes (2kg)", "Strawberries (200g)")
    final weightMatch = RegExp(r'\(([0-9.]+)\s*(kg|g)\)', caseSensitive: false).firstMatch(productName);
    if (weightMatch != null) {
      final weightValue = double.tryParse(weightMatch.group(1) ?? '');
      final weightUnit = weightMatch.group(2)?.toLowerCase();
      
      if (weightValue != null && weightUnit != null) {
        double kgPerUnit;
        if (weightUnit == 'kg') {
          kgPerUnit = weightValue;
        } else if (weightUnit == 'g') {
          kgPerUnit = weightValue / 1000; // Convert grams to kg
        } else {
          return null;
        }
        
        // Calculate total kg needed
        final totalKg = currentQuantity * kgPerUnit;
        print('🔄 CONVERSION: ${currentQuantity} ${originalUnit} of ${productName} = ${totalKg}kg (${kgPerUnit}kg per unit)');
        return totalKg;
      }
    }
    
    // Common conversions for standard packaging
    final productLower = productName.toLowerCase();
    
    // Standard conversions based on product type and packaging
    if (originalUnit.toLowerCase() == 'bag' || productLower.contains('bag')) {
      if (productLower.contains('potato') && productLower.contains('4kg')) {
        return currentQuantity * 4.0; // 4kg potato bags
      } else if (productLower.contains('potato') && productLower.contains('2kg')) {
        return currentQuantity * 2.0; // 2kg potato bags
      } else if (productLower.contains('onion') && productLower.contains('5kg')) {
        return currentQuantity * 5.0; // 5kg onion bags
      }
    } else if (originalUnit.toLowerCase() == 'box' || productLower.contains('box')) {
      if (productLower.contains('tomato') && productLower.contains('2kg')) {
        return currentQuantity * 2.0; // 2kg tomato boxes
      }
    } else if (originalUnit.toLowerCase() == 'punnet') {
      if (productLower.contains('strawberr') || productLower.contains('berry')) {
        return currentQuantity * 0.25; // 250g punnet average
      } else if (productLower.contains('tomato')) {
        return currentQuantity * 0.2; // 200g punnet average
      }
    }
    
    // Default: assume current quantity represents kg if no specific conversion found
    print('🔄 DEFAULT CONVERSION: ${currentQuantity} ${originalUnit} → ${currentQuantity}kg (no specific conversion found)');
    return currentQuantity;
  }

  // Build editable search term widget with edit button and search functionality
  Widget _buildEditableSearchTerm(String originalText, Map<String, dynamic> item) {
    final isSkipped = _skippedItems[originalText] ?? false;
    final isEditing = _isEditingSearch[originalText] ?? false;
    final currentSearchTerm = _editedOriginalText[originalText] ?? originalText;
    final isSearching = _isSearching[originalText] ?? false;
    
    // Get TextEditingController (should already be initialized in _initializeEditedText)
    final searchController = _unitControllers['${originalText}_search'];
    
    // If controller doesn't exist, return simple text widget (should not happen)
    if (searchController == null) {
      return Text(
        currentSearchTerm,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: isSkipped ? Colors.grey : null,
          decoration: isSkipped ? TextDecoration.lineThrough : null,
        ),
      );
    }
    
    // Use ValueKey to ensure TextField rebuilds when search term changes
    // This prevents controller text sync issues during build
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: isEditing
                  ? TextField(
                      key: ValueKey('${originalText}_search_$currentSearchTerm'),
                      controller: searchController,
                      enabled: !isSearching,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: isSkipped ? Colors.grey : null,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        suffixIcon: isSearching
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.search, size: 18),
                                onPressed: () => _rerunSearch(originalText, searchController.text),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                      ),
                    )
                  : InkWell(
                      onTap: () {
                        // Update controller text before entering edit mode
                        if (searchController.text != currentSearchTerm) {
                          searchController.text = currentSearchTerm;
                        }
                        setState(() {
                          _isEditingSearch[originalText] = true;
                          _editedOriginalText[originalText] = currentSearchTerm;
                        });
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              currentSearchTerm,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: isSkipped ? Colors.grey : null,
                                decoration: isSkipped ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          if (!isSkipped)
                            IconButton(
                              icon: const Icon(Icons.edit, size: 16),
                              onPressed: () {
                                // Update controller text before entering edit mode
                                if (searchController.text != currentSearchTerm) {
                                  searchController.text = currentSearchTerm;
                                }
                                setState(() {
                                  _isEditingSearch[originalText] = true;
                                  _editedOriginalText[originalText] = currentSearchTerm;
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Edit search term',
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
        // Show indicator if search term was changed
        if (_editedOriginalText.containsKey(originalText) && _editedOriginalText[originalText] != originalText)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 12, color: Colors.blue),
                const SizedBox(width: 4),
                Text(
                  'Search updated: "$originalText" → "${_editedOriginalText[originalText]}"',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.blue,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Rerun search for a specific item
  Future<void> _rerunSearch(String originalText, String newSearchTerm) async {
    if (newSearchTerm.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a search term'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Update controller text before setState
    final searchController = _unitControllers['${originalText}_search'];
    if (searchController != null && searchController.text != newSearchTerm.trim()) {
      searchController.text = newSearchTerm.trim();
    }
    
    setState(() {
      _isSearching[originalText] = true;
      _isEditingSearch[originalText] = false; // Exit edit mode
      _editedOriginalText[originalText] = newSearchTerm.trim();
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.getProductSuggestions(newSearchTerm.trim());

      if (result['status'] == 'success' && mounted) {
        final suggestions = result['suggestions'] as List<dynamic>? ?? [];
        
        setState(() {
          _updatedSuggestions[originalText] = suggestions;
          _isSearching[originalText] = false;
          
          // Reset selected suggestion since search changed
          _selectedSuggestions.remove(originalText);
          
          // Auto-select best suggestion if available
          if (suggestions.isNotEmpty) {
            // Sort suggestions by confidence and stock availability
            final sortedSuggestions = List<Map<String, dynamic>>.from(suggestions);
            sortedSuggestions.sort((a, b) {
              // Handle confidence_score which might be int or double from backend
              final aScore = (a['confidence_score'] as num?)?.toDouble() ?? 0.0;
              final bScore = (b['confidence_score'] as num?)?.toDouble() ?? 0.0;
              final aInStock = a['in_stock'] as bool? ?? false;
              final bInStock = b['in_stock'] as bool? ?? false;
              
              if (aInStock != bInStock) {
                return bInStock ? 1 : -1;
              }
              return bScore.compareTo(aScore);
            });
            
            _selectedSuggestions[originalText] = sortedSuggestions.first;
            
            // Update unit to match selected product
            final selectedSuggestion = _selectedSuggestions[originalText];
            if (selectedSuggestion != null) {
              final productUnit = selectedSuggestion['unit'] as String? ?? 'each';
              _units[originalText] = productUnit;
              _unitControllers[originalText]?.text = productUnit;
              
              // Set stock action based on product
              final unlimitedStock = selectedSuggestion['unlimited_stock'] as bool? ?? false;
              if (unlimitedStock) {
                _stockActions[originalText] = 'no_reserve';
              } else {
                final inStock = selectedSuggestion['in_stock'] as bool? ?? false;
                _stockActions[originalText] = inStock ? 'reserve' : 'no_reserve';
              }
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${suggestions.length} suggestions for "$newSearchTerm"'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Failed to get suggestions');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching[originalText] = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to search: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

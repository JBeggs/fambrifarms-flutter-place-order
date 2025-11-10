import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../services/api_service.dart';
import '../../../services/pdf_service.dart';
import '../../../services/excel_service.dart';
import '../../../utils/messages_provider.dart';
import '../../../providers/products_provider.dart';

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
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeSelections();
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
        
        // Default to 'reserve' if item is in stock, 'no_reserve' if not in stock
        if (inStock) {
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
    final totalItems = widget.suggestionsData['total_items'] as int? ?? 0;

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
            
            // Items list
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _buildItemCard(item, index);
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _saveChangesAndReprocess,
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('Save Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _confirmOrder,
                    child: _isProcessing 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('Confirm Order ($totalItems items)'),
                  ),
                ),
              ],
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

  Widget _buildItemCard(Map<String, dynamic> item, int index) {
    final originalText = item['original_text'] as String;
    final suggestions = item['suggestions'] as List<dynamic>? ?? [];
    final isParsingFailure = item['is_parsing_failure'] as bool? ?? false;
    final isAmbiguousPackaging = item['is_ambiguous_packaging'] as bool? ?? false;
    
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item number and original text
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    originalText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
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
            
            // Suggestions
            Text(
              'Select Product:',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            
            const SizedBox(height: 6),
            
            if (suggestions.isEmpty)
              const Text(
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
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSuggestions[originalText] = suggestion;
          // Update unit to match the selected suggestion
          _units[originalText] = suggestion['unit'] as String? ?? 'each';
          // Update the unit controller to reflect the change
          _unitControllers[originalText]?.text = suggestion['unit'] as String? ?? 'each';
        });
      },
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 220,
          maxWidth: 400, // Increased width for longer product names
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.green.withValues(alpha: 0.25)
              : Colors.blue.withValues(alpha: 0.1),
          border: Border.all(
            color: isSelected 
                ? Colors.green.shade600
                : Colors.blue.withValues(alpha: 0.3),
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.4),
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
                    color: isSelected ? Colors.green : Colors.blue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isSelected ? 'SELECTED' : 'RECOMMENDED',
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
                if (isSelected) ...[
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
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSuggestions[originalText] = suggestion;
          // Update unit to match the selected suggestion
          _units[originalText] = suggestion['unit'] as String? ?? 'each';
          // Update the unit controller to reflect the change
          _unitControllers[originalText]?.text = suggestion['unit'] as String? ?? 'each';
        });
      },
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 140,
          maxWidth: 250, // Increased from 180 to 250 for longer product names
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.green.shade600
              : Colors.grey.withValues(alpha: 0.1),
          border: Border.all(
            color: isSelected 
                ? Colors.green.shade300
                : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.6),
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

  Future<void> _saveChangesAndReprocess() async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      // Build the updated message content from user's corrections
      final updatedLines = <String>[];
      
      for (final item in widget.suggestionsData['items']) {
        final originalText = item['original_text'] as String;
        final selectedSuggestion = _selectedSuggestions[originalText];
        
        print('💾 SAVE DEBUG: Processing "$originalText"');
        print('💾 Selected: ${selectedSuggestion?['product_name']}');
        
        if (selectedSuggestion != null) {
          // Build corrected line: "ProductName Quantity Unit" with size info preserved
          final rawProductName = selectedSuggestion['product_name'] as String;
          
          // Use user-edited quantity or fallback to parsed quantity
          var quantity = _quantities[originalText] ?? item['parsed']['quantity'];
          
          print('💾 USER QUANTITY: "$originalText" - using quantity: $quantity (from _quantities: ${_quantities[originalText]}, parsed: ${item['parsed']['quantity']})');
          final unit = _units[originalText] ?? selectedSuggestion['unit'] as String; // Use custom unit from UI
          print('💾 USER UNIT: "$originalText" - using unit: "$unit" (from _units: ${_units[originalText]}, suggested: ${selectedSuggestion['unit']}).');
          
          // Extract size info from product name (e.g., "5kg", "200g", "2kg")
          final sizeMatch = RegExp(r'\(([^)]*)\)').firstMatch(rawProductName);
          String sizeInfo = '';
          String baseProductName = rawProductName;
          
          if (sizeMatch != null) {
            sizeInfo = sizeMatch.group(1)!; // e.g., "5kg", "200g punnet", "2kg box"
            baseProductName = rawProductName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
          }
          
          // Create corrected line in CORRECT FORMAT: "Quantity Product Size Unit"
          // GOLD STANDARD: "5 Potatoes 2kg bag", "3 Tomatoes 500g punnet", "2 Carrots 1kg bag"
          String correctedLine;
          
          // Format quantity - ALWAYS include quantity (never omit)
          final formattedQuantity = quantity == quantity.toInt() 
              ? quantity.toInt().toString()
              : quantity.toString();
          
          if (sizeInfo.isNotEmpty) {
            // Has size info from product name: "5kg", "200g punnet", "2kg box"
            // CORRECT FORMAT: "Quantity Product Size" → "10 White Onions 10kg"
            if (sizeInfo.toLowerCase().contains(unit.toLowerCase())) {
              correctedLine = '$formattedQuantity $baseProductName $sizeInfo';
            } else {
              correctedLine = '$formattedQuantity $baseProductName $sizeInfo $unit';
            }
          } else {
            // No size info in brackets, but check if product name has size
            // e.g., "Potatoes (15kg)" → extract "15kg" and combine with unit "bag"
            final productSizeMatch = RegExp(r'\(([^)]*)\)').firstMatch(rawProductName);
            if (productSizeMatch != null) {
              final extractedSize = productSizeMatch.group(1)!; // e.g., "15kg"
              // CORRECT FORMAT: "Quantity Product Size Unit" → "2 Potatoes 15kg bag"
              correctedLine = '$formattedQuantity $baseProductName $extractedSize $unit';
            } else {
              // No size anywhere, use unit only
              // CORRECT FORMAT: "Quantity Product Unit" → "5 Potatoes bag"
              correctedLine = '$formattedQuantity $baseProductName $unit';
            }
          }
          
          print('💾 RAW PRODUCT NAME: "$rawProductName"');
          print('💾 EXTRACTED SIZE INFO: "$sizeInfo"');
          print('💾 SAVE FORMAT: Product="$baseProductName", Qty=$quantity, Unit="$unit", SizeInfo="$sizeInfo"');
          
          // Remove any remaining brackets from final output
          correctedLine = correctedLine.replaceAll(RegExp(r'[()]'), '');
          
          print('💾 SAVE RESULT: "$originalText" → "$correctedLine"');
          updatedLines.add(correctedLine);
        } else {
          // Keep original line if no selection made
          updatedLines.add(originalText);
        }
      }
      
      final updatedContent = updatedLines.join('\n');
      
      print('💾 FINAL UPDATED CONTENT: "$updatedContent"');
      
      // Find the message database ID from the WhatsApp message ID
      final messagesState = ref.read(messagesProvider);
      print('💾 Looking for messageId: ${widget.messageId}');
      print('💾 Available messages count: ${messagesState.messages.length}');
      
      final message = messagesState.messages.firstWhere(
        (msg) => msg.messageId == widget.messageId,
        orElse: () => throw Exception('Message not found')
      );
      
      print('💾 Found message DB ID: ${message.id}');
      print('💾 Current content: "${message.content}"');
      
      // Update the message content via messages provider (handles ID conversion)
      print('💾 Calling editMessage...');
      await ref.read(messagesProvider.notifier).editMessage(message.id, updatedContent);
      print('💾 Edit message completed');
      
      if (mounted) {
        // Force refresh messages to show the updated content
        print('💾 Calling loadMessages to refresh...');
        await ref.read(messagesProvider.notifier).loadMessages();
        print('💾 LoadMessages completed');
        
        // Give UI time to rebuild before closing dialog
        await Future.delayed(const Duration(milliseconds: 300));
        
        if (mounted) {
          Navigator.of(context).pop();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Message updated! Content refreshed.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('💾 ERROR SAVING: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to save changes: $e'),
            backgroundColor: Colors.red,
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

  Future<void> _confirmOrder() async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      // Collect all selected items with their details
      final List<Map<String, dynamic>> orderItems = [];
      
      for (var item in widget.suggestionsData['items']) {
        final originalText = item['original_text'] as String;
        final selectedSuggestion = _selectedSuggestions[originalText];
        final quantity = _quantities[originalText] ?? 1.0;
        final unit = _units[originalText] ?? 'each';
        
        if (selectedSuggestion != null) {
          final stockAction = _stockActions[originalText] ?? 'reserve';
          orderItems.add({
            'product_id': selectedSuggestion['product_id'],
            'product_name': selectedSuggestion['product_name'],
            'quantity': quantity,
            'unit': unit,
            'price': selectedSuggestion['price'],
            'original_text': originalText,
            'stock_action': stockAction,
          });
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
}

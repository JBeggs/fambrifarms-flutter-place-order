import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../services/api_service.dart';
import '../../../utils/messages_provider.dart';

class StockSuggestionsDialog extends ConsumerStatefulWidget {
  final String messageId;
  final Map<String, dynamic> suggestionsData;

  const StockSuggestionsDialog({
    super.key,
    required this.messageId,
    required this.suggestionsData,
  });

  @override
  ConsumerState<StockSuggestionsDialog> createState() => _StockSuggestionsDialogState();
}

class _StockSuggestionsDialogState extends ConsumerState<StockSuggestionsDialog> {
  final Map<String, Map<String, dynamic>> _selectedSuggestions = {};
  final Map<String, double> _quantities = {};
  bool _isProcessing = false;
  bool _resetBeforeProcessing = true;

  @override
  void initState() {
    super.initState();
    _initializeSelections();
  }

  String _formatProductDisplay(Map<String, dynamic> suggestion) {
    final productName = suggestion['product_name'] ?? 'Unknown';
    final unit = suggestion['unit'];
    final currentInventory = suggestion['current_inventory'] ?? 0.0;
    
    // Check if this is a kg conversion option
    final isKgConversion = productName.contains('(kg)') || unit == 'kg';
    
    String displayName = productName;
    
    // If product name already contains packaging info (e.g., "Strawberries (200g)")
    if (productName.contains('(') && productName.contains(')') && !isKgConversion) {
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
            displayName = '$baseName$suffix\n($weightInfo $unitStr)';
          }
        }
      } else {
        // Extract base name and put packaging info on next line
        final regex = RegExp(r'(.*)\s*\(([^)]+)\)(.*)');
        final match = regex.firstMatch(productName);
        if (match != null) {
          final baseName = match.group(1)?.trim() ?? '';
          final packagingInfo = match.group(2) ?? '';
          final suffix = match.group(3) ?? '';
          displayName = '$baseName$suffix\n($packagingInfo)';
        }
      }
    } else if (isKgConversion) {
      // Special formatting for kg conversion options
      if (productName.contains('(kg)')) {
        final baseName = productName.replaceAll(' (kg)', '');
        displayName = '$baseName\n(bulk kg - flexible)';
      } else if (unit == 'kg') {
        // For products like "Button Mushrooms" with unit "kg"
        displayName = '$productName\n(bulk kg - flexible)';
      }
    } else {
      // Otherwise, append the unit on next line
      if (unit != null && unit.toString().isNotEmpty) {
        displayName = '$productName\n($unit)';
      }
    }
    
    // Add inventory info if available
    if (currentInventory > 0) {
      displayName += '\nStock: ${currentInventory.toStringAsFixed(1)} ${unit ?? 'units'}';
    }
    
    return displayName;
  }

  String? _extractUnitFromText(String text) {
    // Extract unit from text like "Cucumber 95 each" -> "each"
    final unitRegex = RegExp(r'\b(kg|g|ml|l|each|head|heads|bunch|bunches|box|boxes|bag|bags|punnet|punnets|packet|packets)\b', caseSensitive: false);
    final match = unitRegex.firstMatch(text.toLowerCase());
    return match?.group(1);
  }

  void _initializeSelections() {
    final items = widget.suggestionsData['items'] as List<dynamic>? ?? [];
    
    for (var item in items) {
      final originalText = item['original_text'] ?? '';
      final suggestions = item['suggestions'] as List<dynamic>? ?? [];
      final parsedQuantity = (item['parsed_quantity'] ?? 1.0).toDouble();
      
      // Initialize quantity
      _quantities[originalText] = parsedQuantity;
      
      // Auto-select best suggestion - prioritize exact package size matches
      if (suggestions.isNotEmpty) {
        Map<String, dynamic>? bestSuggestion;
        
        // Extract package size from original text (e.g., "10kg" from "Potatoes 5 x 10kg bag")
        final packageSizeMatch = RegExp(r'(\d+(?:\.\d+)?)(kg|g|ml|l)').firstMatch(originalText.toLowerCase());
        
        if (packageSizeMatch != null) {
          final packageSize = packageSizeMatch.group(0); // e.g., "10kg"
          
          // DEBUG: Show package size matching for potatoes
          if (originalText.toLowerCase().contains('potatoes')) {
            print('DEBUG PACKAGE SIZE: originalText="$originalText"');
            print('DEBUG PACKAGE SIZE: packageSize="$packageSize"');
            print('DEBUG PACKAGE SIZE: Checking ${suggestions.length} suggestions for "$packageSize"');
          }
          
          // Look for exact package size match first (e.g., "Potatoes (10kg)")
          for (var suggestion in suggestions) {
            final productName = (suggestion['product_name'] ?? '').toLowerCase();
            if (productName.contains(packageSize)) {
              if (originalText.toLowerCase().contains('potatoes')) {
                print('DEBUG PACKAGE SIZE: FOUND MATCH! "${suggestion['product_name']}" contains "$packageSize"');
              }
              bestSuggestion = Map<String, dynamic>.from(suggestion);
              break;
            }
          }
          
          if (packageSizeMatch != null && originalText.toLowerCase().contains('potatoes')) {
            if (bestSuggestion != null) {
              print('DEBUG PACKAGE SIZE: Selected "${bestSuggestion['product_name']}" via package size matching');
            } else {
              print('DEBUG PACKAGE SIZE: No package size match found, falling through to exact match logic');
            }
          }
        }
        
        // If no exact package size match found, pick best suggestion using smart criteria
        if (bestSuggestion == null) {
          // Extract parsed unit from original text (e.g., "each" from "Cucumber 95 each")
          final parsedUnit = _extractUnitFromText(originalText);
          
          // Extract just the product name (remove numbers, units, and packaging)
          final originalLower = originalText.toLowerCase();
          final productNameOnly = originalLower
              .replaceAll(RegExp(r'\d+(?:\.\d+)?\s*(kg|g|ml|l|each|head|heads|bunch|bunches|box|boxes|bag|bags|punnet|punnets|packet|packets)\b'), '')
              .replaceAll(RegExp(r'\b\d+(?:\.\d+)?\b'), '') // Remove standalone numbers
              .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
              .trim();
          
          // FORCE exact matches to the top FIRST, then sort everything else
          final exactMatches = <Map<String, dynamic>>[];
          final nonExactMatches = <Map<String, dynamic>>[];
          
          for (var suggestion in suggestions) {
            final suggestionName = (suggestion['product_name'] ?? '').toString().toLowerCase();
            if (suggestionName == productNameOnly) {
              exactMatches.add(suggestion);
            } else {
              nonExactMatches.add(suggestion);
            }
          }
          
          // Sort exact matches by: 1) Unit match, 2) Confidence
          exactMatches.sort((a, b) {
            final unitA = (a['unit'] ?? '').toString().toLowerCase();
            final unitB = (b['unit'] ?? '').toString().toLowerCase();
            
            // PRIORITY: Unit matching for exact name matches
            final unitMatchA = parsedUnit != null && unitA == parsedUnit.toLowerCase();
            final unitMatchB = parsedUnit != null && unitB == parsedUnit.toLowerCase();
            
            if (unitMatchA != unitMatchB) {
              return unitMatchA ? -1 : 1; // Unit match first
            }
            
            // Secondary: Confidence score
            final confA = (a['confidence_score'] ?? 0.0).toDouble();
            final confB = (b['confidence_score'] ?? 0.0).toDouble();
            return confB.compareTo(confA);
          });
          
          // Sort non-exact matches by: 1) Unit match, 2) Name similarity, 3) Stock level, 4) Confidence
          nonExactMatches.sort((a, b) {
            final nameA = (a['product_name'] ?? '').toString().toLowerCase();
            final nameB = (b['product_name'] ?? '').toString().toLowerCase();
            final unitA = (a['unit'] ?? '').toString().toLowerCase();
            final unitB = (b['unit'] ?? '').toString().toLowerCase();
            final originalLower = originalText.toLowerCase();
            
            // PRIMARY: Unit matching (HIGHEST PRIORITY)
            final unitMatchA = parsedUnit != null && unitA == parsedUnit.toLowerCase();
            final unitMatchB = parsedUnit != null && unitB == parsedUnit.toLowerCase();
            
            if (unitMatchA != unitMatchB) {
              return unitMatchA ? -1 : 1; // Unit match first
            }
            
            // Check name similarity (prefer exact word matches, be strict about product names)
            final wordsA = nameA.split(' ');
            final wordsB = nameB.split(' ');
            
            // productNameOnly is already defined above
            
            // PRIORITY: Exact product name match should win over partial matches
            final exactMatchA = nameA == productNameOnly;
            final exactMatchB = nameB == productNameOnly;
            
            // DEBUG: Show product name extraction for potatoes (removed - using new FORCED sorting)
            
            if (exactMatchA != exactMatchB) {
              // DEBUG: Show when exact match wins
              if (originalLower.contains('potatoes')) {
                print('DEBUG SORTING: EXACT MATCH WINS! "$nameA" (exact=$exactMatchA) vs "$nameB" (exact=$exactMatchB)');
              }
              return exactMatchA ? -1 : 1; // Exact match wins immediately
            }
            
            // Count word matches for secondary sorting
            int matchesA = 0;
            int matchesB = 0;
            
            final List<String> productWords = productNameOnly.split(' ').where((String w) => w.isNotEmpty).toList();
            
            for (String word in productWords) {
              // Exact word match gets higher priority
              if (wordsA.contains(word)) matchesA += 2;
              else if (wordsA.any((String w) => w.contains(word) && word.length > 2)) matchesA += 1;
              
              if (wordsB.contains(word)) matchesB += 2;
              else if (wordsB.any((String w) => w.contains(word) && word.length > 2)) matchesB += 1;
            }
            
            // Light penalty for missing key words (don't be too aggressive)
            for (String word in productWords) {
              if (word.length > 4) { // Only penalize longer, more specific words
                if (!wordsA.any((String w) => w.contains(word))) matchesA -= 1;
                if (!wordsB.any((String w) => w.contains(word))) matchesB -= 1;
              }
            }
            
            // Secondary sort: name similarity
            if (matchesA != matchesB) {
              return matchesB.compareTo(matchesA); // More matches first
            }
            
            // Tertiary sort: stock level
            final stockA = ((a['current_inventory'] ?? 0.0) as num).toDouble();
            final stockB = ((b['current_inventory'] ?? 0.0) as num).toDouble();
            if (stockA != stockB) {
              return stockB.compareTo(stockA); // Higher stock first
            }
            
            // Quaternary sort: confidence score, but prioritize exact matches even with same confidence
            final confA = (a['confidence_score'] ?? 0.0).toDouble();
            final confB = (b['confidence_score'] ?? 0.0).toDouble();
            
            // If confidence scores are equal, prioritize exact matches
            if (confA == confB) {
              // Re-check exact matches as final tie-breaker
              final exactA = nameA == productNameOnly;
              final exactB = nameB == productNameOnly;
              if (exactA != exactB) {
                return exactA ? -1 : 1; // Exact match wins in tie-breaker
              }
            }
            
            return confB.compareTo(confA); // Higher confidence first
          });
          
          // Rebuild suggestions list: exact matches FIRST, then non-exact matches
          suggestions.clear();
          suggestions.addAll(exactMatches);
          suggestions.addAll(nonExactMatches);
          
          bestSuggestion = Map<String, dynamic>.from(suggestions[0]);
          
          // DEBUG: Show auto-selection for potatoes and dill
          if (originalText.toLowerCase().contains('potatoes') || originalText.toLowerCase().contains('dill')) {
            print('DEBUG ${originalText.toUpperCase()}: productNameOnly="$productNameOnly"');
            print('DEBUG ${originalText.toUpperCase()}: Found ${exactMatches.length} exact matches, ${nonExactMatches.length} non-exact matches');
            print('DEBUG ${originalText.toUpperCase()}: parsedUnit="$parsedUnit"');
            
            print('DEBUG ${originalText.toUpperCase()}: Exact matches:');
            for (int i = 0; i < exactMatches.length; i++) {
              final match = exactMatches[i];
              print('  ${i+1}. ${match['product_name']} (Unit: ${match['unit']}) - ${match['confidence_score']}%');
            }
            
            print('DEBUG ${originalText.toUpperCase()}: Auto-selected after FORCED sorting: ${bestSuggestion['product_name']} (Unit: ${bestSuggestion['unit']})');
          }
        }
        
        _selectedSuggestions[originalText] = bestSuggestion;
      }
    }
  }

  Map<String, dynamic> get customer => widget.suggestionsData['customer'] ?? {};
  String get stockDate => widget.suggestionsData['stock_date'] ?? '';
  String get orderDay => widget.suggestionsData['order_day'] ?? '';

  // Check if all items have valid selections
  bool get _allItemsProcessed {
    final items = widget.suggestionsData['items'] as List<dynamic>? ?? [];
    
    for (var item in items) {
      final originalText = item['original_text'] ?? '';
      final suggestions = item['suggestions'] as List<dynamic>? ?? [];
      
      // Item needs a selection if it has suggestions
      if (suggestions.isNotEmpty) {
        if (!_selectedSuggestions.containsKey(originalText)) {
          return false; // No selection made
        }
      }
    }
    return true;
  }

  // Get count of unprocessed items
  int get _unprocessedItemsCount {
    final items = widget.suggestionsData['items'] as List<dynamic>? ?? [];
    int count = 0;
    
    for (var item in items) {
      final originalText = item['original_text'] ?? '';
      final suggestions = item['suggestions'] as List<dynamic>? ?? [];
      
      // Item needs a selection if it has suggestions
      if (suggestions.isNotEmpty) {
        if (!_selectedSuggestions.containsKey(originalText)) {
          count++;
        }
      }
    }
    return count;
  }

  // Get list of unprocessed items for display
  List<String> get _unprocessedItems {
    final items = widget.suggestionsData['items'] as List<dynamic>? ?? [];
    List<String> unprocessed = [];
    
    for (var item in items) {
      final originalText = item['original_text'] ?? '';
      final suggestions = item['suggestions'] as List<dynamic>? ?? [];
      
      // Item needs a selection if it has suggestions
      if (suggestions.isNotEmpty) {
        if (!_selectedSuggestions.containsKey(originalText)) {
          unprocessed.add(originalText);
        }
      }
    }
    return unprocessed;
  }

  /// Sort suggestions for better readability and user experience
  List<Map<String, dynamic>> _getSortedSuggestions(List<dynamic> suggestions, String originalText) {
    if (suggestions.isEmpty) return [];
    
    // Convert to list of maps for easier manipulation
    final suggestionsList = suggestions.cast<Map<String, dynamic>>();
    
    // Group suggestions by product type (base name without size/packaging)
    final Map<String, List<Map<String, dynamic>>> groups = {};
    
    for (var suggestion in suggestionsList) {
      final productName = (suggestion['product_name'] ?? '').toString();
      
      // Extract base product name (remove size, packaging info)
      String baseProduct = _extractBaseProductName(productName);
      
      if (!groups.containsKey(baseProduct)) {
        groups[baseProduct] = [];
      }
      groups[baseProduct]!.add(suggestion);
    }
    
    // Sort groups by relevance to original text
    final sortedGroupKeys = groups.keys.toList()..sort((a, b) {
      final originalLower = originalText.toLowerCase();
      
      // Check which group name is more similar to original
      final aMatches = _calculateNameSimilarity(a.toLowerCase(), originalLower);
      final bMatches = _calculateNameSimilarity(b.toLowerCase(), originalLower);
      
      if (aMatches != bMatches) {
        return bMatches.compareTo(aMatches); // Higher similarity first
      }
      
      // Fallback to alphabetical
      return a.compareTo(b);
    });
    
    // Build final sorted list
    final List<Map<String, dynamic>> sortedSuggestions = [];
    
    for (String groupKey in sortedGroupKeys) {
      final groupSuggestions = groups[groupKey]!;
      
      // Sort within group by package size and stock level
      groupSuggestions.sort((a, b) {
        // First, prioritize selected item
        final selectedId = _selectedSuggestions[originalText]?['product_id'];
        if (a['product_id'] == selectedId) return -1;
        if (b['product_id'] == selectedId) return 1;
        
        // Then sort by package size (extract numeric value)
        final sizeA = _extractPackageSize(a['product_name'] ?? '');
        final sizeB = _extractPackageSize(b['product_name'] ?? '');
        
        if (sizeA != sizeB) {
          return sizeA.compareTo(sizeB); // Smaller sizes first
        }
        
        // Then by stock level (higher stock first)
        final stockA = ((a['current_inventory'] ?? 0.0) as num).toDouble();
        final stockB = ((b['current_inventory'] ?? 0.0) as num).toDouble();
        
        if (stockA != stockB) {
          return stockB.compareTo(stockA);
        }
        
        // Finally by name
        final nameA = (a['product_name'] ?? '').toString();
        final nameB = (b['product_name'] ?? '').toString();
        return nameA.compareTo(nameB);
      });
      
      sortedSuggestions.addAll(groupSuggestions);
    }
    
    return sortedSuggestions;
  }
  
  /// Extract base product name without size/packaging information
  String _extractBaseProductName(String productName) {
    // Remove common size patterns
    String baseName = productName
        .replaceAll(RegExp(r'\s*\(\d+(?:\.\d+)?(?:kg|g|ml|l)\s*(?:bag|box|punnet|packet|bunch)?\)\s*'), '')
        .replaceAll(RegExp(r'\s*\d+(?:\.\d+)?(?:kg|g|ml|l)\s*(?:bag|box|punnet|packet|bunch)?\s*'), '')
        .replaceAll(RegExp(r'\s*\((?:bag|box|punnet|packet|bunch)\)\s*'), '')
        .trim();
    
    // Handle special cases
    if (baseName.isEmpty) {
      baseName = productName; // Fallback to original if extraction failed
    }
    
    return baseName;
  }
  
  /// Extract numeric package size for sorting (returns 0 if no size found)
  double _extractPackageSize(String productName) {
    // Look for patterns like (5kg), 10kg, (2.5kg bag), etc.
    final sizeMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:kg|g|ml|l)').firstMatch(productName.toLowerCase());
    if (sizeMatch != null) {
      final sizeStr = sizeMatch.group(1);
      if (sizeStr != null) {
        final size = double.tryParse(sizeStr) ?? 0.0;
        
        // Convert to grams for consistent comparison
        if (productName.toLowerCase().contains('kg')) {
          return size * 1000;
        } else if (productName.toLowerCase().contains('l')) {
          return size * 1000; // Treat liters as equivalent to kg
        } else {
          return size; // Already in grams or ml
        }
      }
    }
    
    return 0.0; // No size found
  }
  
  /// Calculate name similarity between two strings
  int _calculateNameSimilarity(String name1, String name2) {
    final Set<String> words1 = name1.split(' ').where((String w) => w.isNotEmpty).toSet();
    final Set<String> words2 = name2.split(' ').where((String w) => w.isNotEmpty).toSet();
    
    int matches = 0;
    
    // Exact word matches
    for (String word in words1) {
      if (words2.contains(word)) {
        matches += 2;
      }
    }
    
    // Partial matches (substring)
    for (String word1 in words1) {
      for (String word2 in words2) {
        if (word1 != word2 && word1.length > 2 && word2.length > 2) {
          if (word1.contains(word2) || word2.contains(word1)) {
            matches += 1;
          }
        }
      }
    }
    
    return matches;
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.suggestionsData['items'] as List<dynamic>? ?? [];
    
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.inventory, size: 24, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Confirm Stock Take Items (${items.length} items)',
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
                    const Icon(Icons.store, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Supplier: ${customer['name'] ?? 'Unknown'}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Text(
                      'Date: ${stockDate.split('T')[0]}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
            
            // Reset option
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _resetBeforeProcessing,
                    onChanged: (value) {
                      setState(() {
                        _resetBeforeProcessing = value ?? true;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reset all inventory to 0 before applying',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'This is a complete stock take. All products not listed will be set to 0.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Items list
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _buildItemCard(item, index + 1);
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Validation message for unprocessed items
            if (!_allItemsProcessed) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Processing Blocked',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_unprocessedItemsCount} item${_unprocessedItemsCount == 1 ? '' : 's'} need${_unprocessedItemsCount == 1 ? 's' : ''} product selection before processing:',
                      style: TextStyle(color: Colors.orange.shade700),
                    ),
                    const SizedBox(height: 4),
                    ...(_unprocessedItems.take(3).map((item) => Padding(
                      padding: const EdgeInsets.only(left: 16, top: 2),
                      child: Text(
                        '• $item',
                        style: TextStyle(
                          color: Colors.orange.shade600,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ))),
                    if (_unprocessedItemsCount > 3)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, top: 2),
                        child: Text(
                          '• ... and ${_unprocessedItemsCount - 3} more',
                          style: TextStyle(
                            color: Colors.orange.shade600,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            
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
                  child: OutlinedButton.icon(
                    onPressed: (_isProcessing || !_allItemsProcessed) ? null : _confirmAndNavigateToInventory,
                    icon: const Icon(Icons.inventory),
                    label: const Text('Confirm & View Inventory'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _allItemsProcessed ? Colors.blue : Colors.grey,
                      side: BorderSide(color: _allItemsProcessed ? Colors.blue : Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_isProcessing || !_allItemsProcessed) ? null : _confirmStockUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _allItemsProcessed ? Colors.green : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Confirm Stock Update'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, int itemNumber) {
    final originalText = item['original_text'] ?? '';
    final suggestions = item['suggestions'] as List<dynamic>? ?? [];
    final parsedQuantity = (item['parsed_quantity'] ?? 1.0).toDouble();
    
    // DEBUG: Check what Flutter receives for potatoes
    if (originalText.toLowerCase().contains('potatoes 20 kg')) {
      print('🔍 FLUTTER RECEIVED FOR "Potatoes 20 kg":');
      for (int i = 0; i < suggestions.length && i < 10; i++) {
        final suggestion = suggestions[i];
        print('  ${i+1}. "${suggestion['product_name']}" (Unit: "${suggestion['unit']}") - ${suggestion['confidence_score']}%');
        if (suggestion['product_name'] == 'Potatoes') {
          if (suggestion['unit'] == 'kg') {
            print('     ✅ CORRECT: Found Potatoes with kg unit!');
          } else {
            print('     ❌ WRONG: Potatoes has unit "${suggestion['unit']}" instead of "kg"!');
          }
        }
      }
    }
    
    final selectedSuggestion = _selectedSuggestions[originalText];
    final currentQuantity = _quantities[originalText] ?? parsedQuantity;
    
    // Check if this item needs attention (has suggestions but no selection)
    final needsAttention = suggestions.isNotEmpty && selectedSuggestion == null;
    
    // Group suggestions by department
    final Map<String, List<Map<String, dynamic>>> groupedSuggestions = {};
    for (var suggestion in suggestions) {
      final department = suggestion['department'] ?? 'Other';
      groupedSuggestions.putIfAbsent(department, () => []);
      groupedSuggestions[department]!.add(Map<String, dynamic>.from(suggestion));
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: needsAttention ? Colors.orange.withValues(alpha: 0.05) : null,
      shape: needsAttention ? RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.withValues(alpha: 0.3), width: 2),
      ) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item header with number and original text
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '$itemNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Original: $originalText',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (needsAttention) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'NEEDS SELECTION',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (selectedSuggestion != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Selected: ${_formatProductDisplay(selectedSuggestion)}',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: selectedSuggestion != null ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    selectedSuggestion != null ? 'SELECTED' : 'NEEDS SELECTION',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Quantity input
            Row(
              children: [
                const Text('Quantity:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    initialValue: currentQuantity.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    onChanged: (value) {
                      final quantity = double.tryParse(value) ?? parsedQuantity;
                      setState(() {
                        _quantities[originalText] = quantity;
                      });
                    },
                  ),
                ),
                if (selectedSuggestion != null) ...[
                  const SizedBox(width: 16),
                  Text(
                    'Current: ${selectedSuggestion['current_inventory']?.toStringAsFixed(1) ?? '0'} ${selectedSuggestion['unit'] ?? ''}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    currentQuantity > (selectedSuggestion['current_inventory'] ?? 0)
                        ? Icons.trending_up
                        : currentQuantity < (selectedSuggestion['current_inventory'] ?? 0)
                            ? Icons.trending_down
                            : Icons.trending_flat,
                    color: currentQuantity > (selectedSuggestion['current_inventory'] ?? 0)
                        ? Colors.green
                        : currentQuantity < (selectedSuggestion['current_inventory'] ?? 0)
                            ? Colors.red
                            : Colors.grey,
                    size: 16,
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Suggestions grouped by department
            if (suggestions.isNotEmpty) ...[
              const Text(
                'Select Product:',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
              ),
              const SizedBox(height: 8),
              _buildSuggestionsList(groupedSuggestions, originalText),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'No product suggestions found',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsList(Map<String, List<Map<String, dynamic>>> groupedSuggestions, String originalText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groupedSuggestions.entries.map((entry) {
        final department = entry.key;
        final suggestions = entry.value;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Department header
            if (groupedSuggestions.length > 1) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  department,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
            
            // Suggestions grid with improved ordering
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _getSortedSuggestions(suggestions, originalText).map((suggestion) {
                final isSelected = _selectedSuggestions[originalText]?['product_id'] == suggestion['product_id'];
                
                if (isSelected) {
                  // Prominent suggestion (selected one)
                  return _buildProminentSuggestion(suggestion, originalText);
                } else {
                  // Compact suggestion
                  return _buildCompactSuggestion(suggestion, originalText);
                }
              }).toList(),
            ),
            
            const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildProminentSuggestion(Map<String, dynamic> suggestion, String originalText) {
    final isSelected = _selectedSuggestions[originalText]?['product_id'] == suggestion['product_id'];
    final isKgConversion = (suggestion['product_name'] ?? '').contains('(kg)') || suggestion['unit'] == 'kg';
    
    // Choose colors based on kg conversion status
    final primaryColor = isKgConversion ? Colors.orange : Colors.blue;
    final selectedColor = isSelected ? Colors.green : primaryColor;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSuggestions[originalText] = suggestion;
        });
      },
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 220,
          maxWidth: 320,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.green.withValues(alpha: 0.15)
              : primaryColor.withValues(alpha: 0.1),
          border: Border.all(
            color: selectedColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.3),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ] : isKgConversion ? [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.2),
              blurRadius: 2,
              spreadRadius: 0,
            ),
          ] : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selectedColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isKgConversion ? 'KG BULK' : 'RECOMMENDED',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _formatProductDisplay(suggestion),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.green[300] : Colors.grey[100],
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  Widget _buildCompactSuggestion(Map<String, dynamic> suggestion, String originalText) {
    final isSelected = _selectedSuggestions[originalText]?['product_id'] == suggestion['product_id'];
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSuggestions[originalText] = suggestion;
        });
      },
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 140,
          maxWidth: 180,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.green.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.1),
          border: Border.all(
            color: isSelected 
                ? Colors.green
                : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.3),
              blurRadius: 3,
              spreadRadius: 1,
            ),
          ] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatProductDisplay(suggestion),
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.green[300] : Colors.grey[100],
                fontSize: 12,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
          ],
        ),
      ),
    );
  }

  Future<void> _confirmStockUpdate() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Collect all confirmed items
      final confirmedItems = <Map<String, dynamic>>[];
      
      for (var entry in _selectedSuggestions.entries) {
        final originalText = entry.key;
        final suggestion = entry.value;
        final quantity = _quantities[originalText] ?? 1.0;
        
        confirmedItems.add({
          'product_id': suggestion['product_id'],
          'quantity': quantity,
          'unit': suggestion['unit'],
          'original_text': originalText,
        });
      }
      
      if (confirmedItems.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select at least one product'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Create stock update
      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.createStockUpdateFromSuggestions(
        messageId: widget.messageId,
        confirmedItems: confirmedItems,
        stockDate: stockDate,
        orderDay: orderDay,
        resetBeforeProcessing: _resetBeforeProcessing,
      );
      
      if (mounted) {
        if (result['status'] == 'success') {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Stock update created successfully'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Close dialog
          Navigator.of(context).pop(true);
          
          // Refresh messages
          await ref.read(messagesProvider.notifier).loadMessages(
            page: 1, 
            pageSize: 20
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to create stock update'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating stock update: $e'),
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

  Future<void> _confirmAndNavigateToInventory() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Collect all confirmed items
      final confirmedItems = <Map<String, dynamic>>[];
      
      for (var entry in _selectedSuggestions.entries) {
        final originalText = entry.key;
        final suggestion = entry.value;
        final quantity = _quantities[originalText] ?? 1.0;
        
        confirmedItems.add({
          'product_id': suggestion['product_id'],
          'quantity': quantity,
          'unit': suggestion['unit'],
          'original_text': originalText,
        });
      }
      
      if (confirmedItems.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select at least one product'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Create stock update
      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.createStockUpdateFromSuggestions(
        messageId: widget.messageId,
        confirmedItems: confirmedItems,
        stockDate: stockDate,
        orderDay: orderDay,
        resetBeforeProcessing: _resetBeforeProcessing,
      );
      
      if (mounted) {
        if (result['status'] == 'success') {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${result['message'] ?? 'Stock update created successfully'} - Navigating to inventory...'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // Close dialog
          Navigator.of(context).pop(true);
          
          // Navigate to inventory management
          context.go('/inventory');
          
          // Refresh messages in background
          ref.read(messagesProvider.notifier).loadMessages(
            page: 1, 
            pageSize: 20
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to create stock update'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating stock update: $e'),
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
}

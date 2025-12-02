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
import '../../../utils/stock_formatter.dart';
import '../../../utils/packaging_size_parser.dart';
import '../../../providers/products_provider.dart';
import '../../../models/product.dart' as product_model;
import '../utils/order_items_persistence.dart';

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
  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, bool> _skippedItems = {}; // Track items that should be skipped
  // Source product for stock deduction
  final Map<String, bool> _useSourceProduct = {}; // Track if source product is used per item
  final Map<String, Map<String, dynamic>> _selectedSourceProducts = {}; // Source product per item
  final Map<String, double> _sourceQuantities = {}; // Source quantity per item (in native unit after conversion)
  final Map<String, String> _sourceQuantityUnits = {}; // Input unit: 'head' (native) or 'kg'
  final Map<String, TextEditingController> _sourceQuantityControllers = {};
  // Track edited original text and loading state for search
  final Map<String, String> _editedOriginalText = {}; // Store edited search terms
  final Map<String, bool> _isEditingSearch = {}; // Track if user is currently editing search term
  final Map<String, bool> _isSearching = {}; // Track if search is in progress per item
  final Map<String, List<dynamic>> _updatedSuggestions = {}; // Store updated suggestions per item
  bool _isProcessing = false;
  late List<Map<String, dynamic>> _items; // Mutable list of items
  final ScrollController _scrollController = ScrollController();
  bool _showCustomerInfo = true; // Show initially

  @override
  void initState() {
    super.initState();
    // Initialize mutable items list from widget data
    final rawItems = widget.suggestionsData['items'] as List<dynamic>? ?? [];
    _items = rawItems.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    _initializeSelections();
    _initializeEditedText();
    
    // Listen to scroll to hide customer info after scrolling
    _scrollController.addListener(() {
      if (_scrollController.offset > 100 && _showCustomerInfo) {
        setState(() {
          _showCustomerInfo = false;
        });
      } else if (_scrollController.offset <= 100 && !_showCustomerInfo) {
        setState(() {
          _showCustomerInfo = true;
        });
      }
    });
    
    // Check for saved progress and offer to restore
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForSavedProgress();
    });
  }

  // Initialize edited original text map with original values
  void _initializeEditedText() {
    for (var item in _items) {
      final originalText = item['original_text'] as String;
      _editedOriginalText[originalText] = originalText;
      // Initialize search controllers
      if (!_unitControllers.containsKey('${originalText}_search')) {
        _unitControllers['${originalText}_search'] = TextEditingController(text: originalText);
      }
    }
  }

  // Add a new item after the specified index
  Future<void> _addNewItem(int afterIndex) async {
    final TextEditingController searchController = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Item'),
        content: TextField(
          controller: searchController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Search for product',
            hintText: 'e.g., 2kg tomatoes',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (searchController.text.trim().isNotEmpty) {
                Navigator.of(context).pop({
                  'search_text': searchController.text.trim(),
                });
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result['search_text'] != null) {
      final searchText = result['search_text'] as String;
      
      final newItem = {
        'original_text': searchText,
        'suggestions': <Map<String, dynamic>>[],
        'is_parsing_failure': false,
        'is_ambiguous_packaging': false,
      };

      setState(() {
        _items.insert(afterIndex + 1, newItem);
        _editedOriginalText[searchText] = searchText;
        _quantities[searchText] = 1.0;
        _units[searchText] = 'each';
        _quantityControllers[searchText] = TextEditingController(text: '1');
        _unitControllers[searchText] = TextEditingController(text: 'each');
        _unitControllers['${searchText}_search'] = TextEditingController(text: searchText);
        _sourceQuantityControllers[searchText] = TextEditingController();
        _skippedItems[searchText] = false;
      });

      // Use existing search functionality
      await _rerunSearch(searchText, searchText);
    }
  }

  // Edit search criteria for an item
  Future<void> _editSearchCriteria(String originalText, int index) async {
    final controller = TextEditingController(text: _editedOriginalText[originalText] ?? originalText);
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Search Criteria'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Search text',
            hintText: 'Enter new search criteria',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(context).pop({
                  'new_search': controller.text.trim(),
                });
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result != null && result['new_search'] != null) {
      final newSearch = result['new_search'] as String;
      
      setState(() {
        // Update the item's original text
        final itemIndex = _items.indexWhere((item) => item['original_text'] == originalText);
        if (itemIndex != -1) {
          // Create new item with updated text
          final updatedItem = Map<String, dynamic>.from(_items[itemIndex]);
          updatedItem['original_text'] = newSearch;
          
          // Update all state maps with new key
          if (originalText != newSearch) {
            // Migrate state to new key
            _selectedSuggestions[newSearch] = _selectedSuggestions.remove(originalText) ?? {};
            _quantities[newSearch] = _quantities.remove(originalText) ?? 1.0;
            _units[newSearch] = _units.remove(originalText) ?? 'each';
            _stockActions[newSearch] = _stockActions.remove(originalText) ?? 'reserve';
            _skippedItems[newSearch] = _skippedItems.remove(originalText) ?? false;
            _useSourceProduct[newSearch] = _useSourceProduct.remove(originalText) ?? false;
            _selectedSourceProducts[newSearch] = _selectedSourceProducts.remove(originalText) ?? {};
            _sourceQuantities[newSearch] = _sourceQuantities.remove(originalText) ?? 0.0;
            _sourceQuantityUnits[newSearch] = _sourceQuantityUnits.remove(originalText) ?? 'each';
            _updatedSuggestions[newSearch] = _updatedSuggestions.remove(originalText) ?? [];
            _editedOriginalText[newSearch] = newSearch;
            
            // Update controllers
            _quantityControllers[newSearch] = _quantityControllers.remove(originalText) ?? TextEditingController(text: '1');
            _unitControllers[newSearch] = _unitControllers.remove(originalText) ?? TextEditingController(text: 'each');
            _unitControllers['${newSearch}_search'] = _unitControllers.remove('${originalText}_search') ?? TextEditingController(text: newSearch);
            _sourceQuantityControllers[newSearch] = _sourceQuantityControllers.remove(originalText) ?? TextEditingController();
            
            _items[itemIndex] = updatedItem;
          } else {
            _editedOriginalText[newSearch] = newSearch;
            if (_unitControllers.containsKey('${originalText}_search')) {
              _unitControllers['${originalText}_search']?.text = newSearch;
            }
          }
        }
      });

      // Fetch new suggestions using existing search method
      await _rerunSearch(newSearch, newSearch);
    }
  }

  /// Check for saved progress and offer to restore
  Future<void> _checkForSavedProgress() async {
    try {
      final savedData = await OrderItemsPersistence.loadSavedProgress(widget.messageId);
      if (savedData != null && mounted) {
        final changedCount = (savedData['selectedSuggestions'] as Map<String, dynamic>? ?? {}).length;
        final unprocessedCount = (savedData['unprocessedItems'] as List<dynamic>? ?? []).length;
        
        if (changedCount > 0 || unprocessedCount > 0) {
          _showRestoreDialog(savedData, changedCount, unprocessedCount);
        }
      }
    } catch (e) {
      print('[ORDER_ITEMS] Error checking for saved progress: $e');
    }
  }
  
  /// Show restore dialog
  Future<void> _showRestoreDialog(Map<String, dynamic> savedData, int changedCount, int unprocessedCount) async {
    if (!mounted) return;
    
    final timestamp = savedData['timestamp'] as String?;
    final timestampStr = timestamp != null 
        ? DateTime.parse(timestamp).toString().split('.')[0]
        : 'unknown time';
    
    final shouldRestore = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Saved Progress?'),
        content: Text(
          'Found saved progress from $timestampStr with:\n'
          '• $changedCount processed items\n'
          '• $unprocessedCount unprocessed items\n\n'
          'Restore it?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No, Start Fresh'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, Restore'),
          ),
        ],
      ),
    );
    
    if (shouldRestore == true && mounted) {
      _restoreProgress(savedData);
    }
  }
  
  /// Restore progress from saved data
  void _restoreProgress(Map<String, dynamic> savedData) {
    try {
      print('[ORDER_ITEMS] Restoring saved progress');
      
      // Restore changed items
      final savedSelectedSuggestions = savedData['selectedSuggestions'] as Map<String, dynamic>? ?? {};
      final savedQuantities = savedData['quantities'] as Map<String, dynamic>? ?? {};
      final savedUnits = savedData['units'] as Map<String, dynamic>? ?? {};
      final savedStockActions = savedData['stockActions'] as Map<String, dynamic>? ?? {};
      final savedSkippedItems = savedData['skippedItems'] as Map<String, dynamic>? ?? {};
      final savedUseSourceProduct = savedData['useSourceProduct'] as Map<String, dynamic>? ?? {};
      final savedSelectedSourceProducts = savedData['selectedSourceProducts'] as Map<String, dynamic>? ?? {};
      final savedSourceQuantities = savedData['sourceQuantities'] as Map<String, dynamic>? ?? {};
      final savedSourceQuantityUnits = savedData['sourceQuantityUnits'] as Map<String, dynamic>? ?? {};
      final savedEditedOriginalText = savedData['editedOriginalText'] as Map<String, dynamic>? ?? {};
      final unprocessedItems = (savedData['unprocessedItems'] as List<dynamic>? ?? []).cast<String>();
      
      setState(() {
        // Restore changed items
        for (final entry in savedSelectedSuggestions.entries) {
          _selectedSuggestions[entry.key] = Map<String, dynamic>.from(entry.value as Map);
        }
        
        for (final entry in savedQuantities.entries) {
          _quantities[entry.key] = (entry.value as num).toDouble();
        }
        
        for (final entry in savedUnits.entries) {
          _units[entry.key] = entry.value as String;
        }
        
        for (final entry in savedStockActions.entries) {
          _stockActions[entry.key] = entry.value as String;
        }
        
        for (final entry in savedSkippedItems.entries) {
          if (entry.value.toString().toLowerCase() == 'true') {
            _skippedItems[entry.key] = true;
          }
        }
        
        for (final entry in savedUseSourceProduct.entries) {
          if (entry.value.toString().toLowerCase() == 'true') {
            _useSourceProduct[entry.key] = true;
          }
        }
        
        for (final entry in savedSelectedSourceProducts.entries) {
          _selectedSourceProducts[entry.key] = Map<String, dynamic>.from(entry.value as Map);
        }
        
        for (final entry in savedSourceQuantities.entries) {
          _sourceQuantities[entry.key] = (entry.value as num).toDouble();
        }
        
        for (final entry in savedSourceQuantityUnits.entries) {
          _sourceQuantityUnits[entry.key] = entry.value as String;
        }
        
        for (final entry in savedEditedOriginalText.entries) {
          _editedOriginalText[entry.key] = entry.value as String;
        }
        
        // Restore controllers for changed items
        for (final originalText in savedSelectedSuggestions.keys) {
          // Restore quantity controller
          if (_quantities[originalText] != null) {
            final qty = _quantities[originalText]!;
            _quantityControllers[originalText] = TextEditingController(
              text: qty == qty.toInt() ? qty.toInt().toString() : qty.toString(),
            );
          }
          
          // Restore unit controller
          if (_units[originalText] != null) {
            _unitControllers[originalText] = TextEditingController(text: _units[originalText]);
          }
          
          // Restore search controller
          final editedText = _editedOriginalText[originalText] ?? originalText;
          _unitControllers['${originalText}_search'] = TextEditingController(text: editedText);
          
          // Restore source quantity controller
          if (_sourceQuantities[originalText] != null) {
            final srcQty = _sourceQuantities[originalText]!;
            _sourceQuantityControllers[originalText] = TextEditingController(
              text: srcQty == srcQty.toInt() ? srcQty.toInt().toString() : srcQty.toString(),
            );
          } else {
            _sourceQuantityControllers[originalText] = TextEditingController();
          }
        }
        
        // Ensure unprocessed items remain in _items (they should already be there)
        // Filter _items to keep only items that are either changed or unprocessed
        final allProcessedKeys = savedSelectedSuggestions.keys.toSet();
        final unprocessedSet = unprocessedItems.toSet();
        
        // Keep items that are either changed or unprocessed
        _items = _items.where((item) {
          final originalText = item['original_text'] as String;
          return allProcessedKeys.contains(originalText) || unprocessedSet.contains(originalText);
        }).toList();
        
        // Ensure unprocessed items have their controllers initialized
        for (final originalText in unprocessedItems) {
          if (!_quantityControllers.containsKey(originalText)) {
            final item = _items.firstWhere(
              (i) => i['original_text'] == originalText,
              orElse: () => <String, dynamic>{},
            );
            if (item.isNotEmpty) {
              final parsed = item['parsed'] as Map<String, dynamic>? ?? {};
              final qty = (parsed['quantity'] as num?)?.toDouble() ?? 1.0;
              _quantities[originalText] = qty;
              _units[originalText] = parsed['unit'] as String? ?? 'each';
              _quantityControllers[originalText] = TextEditingController(
                text: qty == qty.toInt() ? qty.toInt().toString() : qty.toString(),
              );
              _unitControllers[originalText] = TextEditingController(text: _units[originalText]);
              _unitControllers['${originalText}_search'] = TextEditingController(text: originalText);
              _sourceQuantityControllers[originalText] = TextEditingController();
            }
          }
        }
      });
      
      print('[ORDER_ITEMS] Restored ${savedSelectedSuggestions.length} changed items and ${unprocessedItems.length} unprocessed items');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Progress restored successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('[ORDER_ITEMS] Error restoring progress: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error restoring progress: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // Auto-save progress on dispose
    _saveProgressSilently();
    
    // Dispose scroll controller
    _scrollController.dispose();
    // Dispose all text controllers
    for (var controller in _unitControllers.values) {
      controller.dispose();
    }
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    for (var controller in _sourceQuantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
  
  /// Save progress silently (no snackbar) - used for auto-save
  Future<void> _saveProgressSilently() async {
    try {
      // Filter only changed items
      final changedItems = <String>[];
      final unprocessedItems = <String>[];
      
      for (var item in _items) {
        final originalText = item['original_text'] as String;
        if (_isItemChanged(originalText)) {
          changedItems.add(originalText);
        } else {
          unprocessedItems.add(originalText);
        }
      }
      
      // Only save if there are changed items
      if (changedItems.isEmpty && unprocessedItems.isEmpty) {
        return;
      }
      
      // Build filtered maps for changed items only
      final filteredSelectedSuggestions = <String, Map<String, dynamic>>{};
      final filteredQuantities = <String, double>{};
      final filteredUnits = <String, String>{};
      final filteredStockActions = <String, String>{};
      final filteredSkippedItems = <String, bool>{};
      final filteredUseSourceProduct = <String, bool>{};
      final filteredSelectedSourceProducts = <String, Map<String, dynamic>>{};
      final filteredSourceQuantities = <String, double>{};
      final filteredSourceQuantityUnits = <String, String>{};
      final filteredEditedOriginalText = <String, String>{};
      
      for (final originalText in changedItems) {
        if (_selectedSuggestions[originalText] != null) {
          filteredSelectedSuggestions[originalText] = _selectedSuggestions[originalText]!;
        }
        if (_quantities[originalText] != null) {
          filteredQuantities[originalText] = _quantities[originalText]!;
        }
        if (_units[originalText] != null) {
          filteredUnits[originalText] = _units[originalText]!;
        }
        if (_stockActions[originalText] != null) {
          filteredStockActions[originalText] = _stockActions[originalText]!;
        }
        if (_skippedItems[originalText] == true) {
          filteredSkippedItems[originalText] = true;
        }
        if (_useSourceProduct[originalText] == true) {
          filteredUseSourceProduct[originalText] = true;
        }
        if (_selectedSourceProducts[originalText] != null) {
          filteredSelectedSourceProducts[originalText] = _selectedSourceProducts[originalText]!;
        }
        if (_sourceQuantities[originalText] != null) {
          filteredSourceQuantities[originalText] = _sourceQuantities[originalText]!;
        }
        if (_sourceQuantityUnits[originalText] != null) {
          filteredSourceQuantityUnits[originalText] = _sourceQuantityUnits[originalText]!;
        }
        if (_editedOriginalText[originalText] != null && _editedOriginalText[originalText] != originalText) {
          filteredEditedOriginalText[originalText] = _editedOriginalText[originalText]!;
        }
      }
      
      await OrderItemsPersistence.saveProgress(
        messageId: widget.messageId,
        selectedSuggestions: filteredSelectedSuggestions,
        quantities: filteredQuantities,
        units: filteredUnits,
        stockActions: filteredStockActions,
        skippedItems: filteredSkippedItems,
        useSourceProduct: filteredUseSourceProduct,
        selectedSourceProducts: filteredSelectedSourceProducts,
        sourceQuantities: filteredSourceQuantities,
        sourceQuantityUnits: filteredSourceQuantityUnits,
        editedOriginalText: filteredEditedOriginalText,
        unprocessedItems: unprocessedItems,
        showSnackbar: false,
        context: null,
      );
      
      print('[ORDER_ITEMS] Auto-saved progress on dispose');
    } catch (e) {
      print('[ORDER_ITEMS] Error auto-saving progress: $e');
      // Don't show error on auto-save
    }
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

  // Helper function to format stock quantity display
  // Use shared utility for formatting stock quantities
  String _formatStockQuantity({
    required String unit,
    int? count,
    double? weightKg,
  }) {
    return formatStockQuantity(
      unit: unit,
      count: count,
      weightKg: weightKg,
    );
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
    
    // Use backend-provided count and weight values
    final availableCount = (stock['available_quantity_count'] as num?)?.toInt();
    final availableWeightKg = (stock['available_quantity_kg'] as num?)?.toDouble();
    final reservedCount = (stock['reserved_quantity_count'] as num?)?.toInt();
    final reservedWeightKg = (stock['reserved_quantity_kg'] as num?)?.toDouble();
    
    // Fallback to original available_quantity if new fields not available (backward compatibility)
    final available = availableCount != null || availableWeightKg != null
        ? ((availableCount ?? 0) > 0 || (availableWeightKg ?? 0) > 0)
        : ((stock['available_quantity'] as num?)?.toDouble() ?? 0.0) > 0;
    
    final reserved = reservedCount != null || reservedWeightKg != null
        ? ((reservedCount ?? 0) > 0 || (reservedWeightKg ?? 0) > 0)
        : ((stock['reserved_quantity'] as num?)?.toDouble() ?? 0.0) > 0;
    
    final unit = suggestion['unit'] as String? ?? 'each';
    
    String statusText;
    Color bgColor;
    Color textColor;
    
    if (available) {
      // Use new format with count and weight
      final availableDisplay = _formatStockQuantity(
        unit: unit,
        count: availableCount,
        weightKg: availableWeightKg,
      );
      // For kg products: add "kg" if not already in display
      // For discrete products: formatStockQuantity includes "kg" for weight inside parentheses, append product unit
      final unitLower = unit.toLowerCase();
      final displayWithUnit = (unitLower == 'kg' || unitLower == 'g' || unitLower == 'ml' || unitLower == 'l')
          ? (availableDisplay.contains('kg') || availableDisplay.contains('g') || availableDisplay.contains('ml') || availableDisplay.contains('l')
              ? '$availableDisplay AVAIL'
              : '$availableDisplay $unit AVAIL')
          : '$availableDisplay $unit AVAIL';
      statusText = displayWithUnit;
      bgColor = Colors.green.withValues(alpha: 0.2);
      textColor = Colors.green.shade700;
      if (reserved) {
        final reservedDisplay = _formatStockQuantity(
          unit: unit,
          count: reservedCount,
          weightKg: reservedWeightKg,
        );
        final reservedWithUnit = (unitLower == 'kg' || unitLower == 'g' || unitLower == 'ml' || unitLower == 'l')
            ? (reservedDisplay.contains('kg') || reservedDisplay.contains('g') || reservedDisplay.contains('ml') || reservedDisplay.contains('l')
                ? '$reservedDisplay res'
                : '$reservedDisplay $unit res')
            : '$reservedDisplay $unit res';
        statusText += ' ($reservedWithUnit)';
      }
    } else if (reserved) {
      final reservedDisplay = _formatStockQuantity(
        unit: unit,
        count: reservedCount,
        weightKg: reservedWeightKg,
      );
      final unitLower = unit.toLowerCase();
      final reservedWithUnit = (unitLower == 'kg' || unitLower == 'g' || unitLower == 'ml' || unitLower == 'l')
          ? (reservedDisplay.contains('kg') || reservedDisplay.contains('g') || reservedDisplay.contains('ml') || reservedDisplay.contains('l')
              ? '$reservedDisplay RES ONLY'
              : '$reservedDisplay $unit RES ONLY')
          : '$reservedDisplay $unit RES ONLY';
      statusText = reservedWithUnit;
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
    // Use _items which is initialized from widget.suggestionsData['items'] in initState
    for (var item in _items) {
      final originalText = item['original_text'] as String;
      final parsed = item['parsed'] as Map<String, dynamic>;
      final suggestions = item['suggestions'] as List<dynamic>? ?? [];
      
      // Don't auto-select here - we'll do it after sorting for better selection
      
      // Initialize quantities and units from parsed data
      _quantities[originalText] = (parsed['quantity'] as num?)?.toDouble() ?? 1.0;
      _units[originalText] = parsed['unit'] as String? ?? 'each';
      
      // Initialize TextEditingController for quantity editing
      final quantityValue = _quantities[originalText]!;
      _quantityControllers[originalText] = TextEditingController(
        text: quantityValue == quantityValue.toInt() 
            ? quantityValue.toInt().toString() 
            : quantityValue.toString(),
      );
      
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
        
        // DISABLED: Automatic selection - users must manually select
        // First try to find a product with the matching unit
        // final parsedUnit = _units[originalText];
        // Map<String, dynamic>? unitMatch;
        // 
        // for (var suggestion in sortedSuggestions) {
        //   if (suggestion['unit'].toString().toLowerCase() == parsedUnit?.toLowerCase()) {
        //     unitMatch = suggestion;
        //     break;
        //   }
        // }
        // 
        // _selectedSuggestions[originalText] = unitMatch ?? sortedSuggestions.first;
        // 
        // // CRITICAL FIX: Update unit to match the auto-selected product
        // final autoSelected = _selectedSuggestions[originalText];
        // if (autoSelected != null) {
        //   final productUnit = autoSelected['unit'] as String? ?? 'each';
        //   _units[originalText] = productUnit;
        //   _unitControllers[originalText]?.text = productUnit;
        // }
      } 
      // DISABLED: Automatic selection fallback - users must manually select
      // else if (suggestions.isNotEmpty) {
      //   // Fallback: if no suggestions after sorting, use the first original suggestion
      //   _selectedSuggestions[originalText] = suggestions.first;
      //   
      //   // CRITICAL FIX: Update unit to match the auto-selected product
      //   final autoSelected = _selectedSuggestions[originalText];
      //   if (autoSelected != null) {
      //     final productUnit = autoSelected['unit'] as String? ?? 'each';
      //     _units[originalText] = productUnit;
      //     _unitControllers[originalText]?.text = productUnit;
      //   }
      // }
      
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
    // Use mutable items list
    final items = _items;
    
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
            
            // Customer info - only show after scrolling a bit
            if (customer.isNotEmpty && _showCustomerInfo) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business, size: 14, color: Colors.blue),
                    const SizedBox(width: 6),
                    Text(
                      'Customer: ${customer['name'] ?? 'Unknown'}',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 8),
            
            // Items list with confirm button at the end
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: items.length + (allItemsCompleted ? 1 : 0) + (!allItemsCompleted ? 1 : 0), // Add 1 for button if all completed, add 1 for "complete all items" message if not completed
                itemBuilder: (context, index) {
                  // If this is the last item and all items are completed, show confirm button
                  if (allItemsCompleted && index == items.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          children: [
                            // Progress indicator showing completion
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'All items completed ($completedItemsCount/$includedItemsCount)',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Save Progress button
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: _isProcessing ? null : _saveProgress,
                                icon: const Icon(Icons.save, size: 18),
                                label: const Text(
                                  'Save Progress',
                                  style: TextStyle(fontSize: 15),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.blue),
                                  foregroundColor: Colors.blue,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Preview button - shows Excel preview
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: _isProcessing ? null : _previewOrderExcel,
                                icon: const Icon(Icons.preview, size: 18),
                                label: const Text(
                                  'Preview Excel',
                                  style: TextStyle(fontSize: 15),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Theme.of(context).primaryColor),
                                  foregroundColor: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Confirm Order button - bigger and prominent
                            SizedBox(
                              width: double.infinity,
                              height: 52,
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
                                          const Icon(Icons.check_circle, size: 22),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Confirm Order ($includedItemsCount items)',
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Cancel button - smaller, less prominent
                            TextButton(
                              onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  // Show "Complete all items" message at the end of items (before buttons) if not all completed
                  if (!allItemsCompleted && index == items.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange.shade700, size: 16),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Complete all items to confirm order ($completedItemsCount/$includedItemsCount)',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11,
                                ),
                                textAlign: TextAlign.center,
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
          ],
    );

    // Return content wrapped in Dialog for desktop, or directly for mobile Scaffold
    if (isInScaffold) {
      // Mobile: return content directly (already in Scaffold with AppBar)
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    // Otherwise, find the item in our mutable list and return its suggestions
    for (var item in _items) {
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

    // Get screen height and make card full height
    final screenHeight = MediaQuery.of(context).size.height;
    return SizedBox(
      height: screenHeight * 0.75, // Use 85% of screen height for the card
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: isSkipped ? Colors.grey.withValues(alpha: 0.2) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
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
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  onPressed: () => _addNewItem(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Add item below',
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
            
            // Show original vs edited comparison (centered)
            if (selectedSuggestion != null) ...[
              const SizedBox(height: 6),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Original: $originalText',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Edited: $editedText',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 8),
            
            // Centered quantity and unit editing with source product checkbox
            Center(
              child: Column(
                children: [
                  // Select Product label (centered)
                  Text(
                    'Select Product:',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  // Quantity and unit fields (centered)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Qty:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 60,
                        height: 28,
                        child: TextFormField(
                          key: ValueKey('${originalText}_quantity'), // Stable key for quantity field
                          controller: _quantityControllers[originalText],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 11),
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          ),
                          onTap: () {
                            // Ensure keyboard appears when tapping the field
                            FocusScope.of(context).requestFocus(FocusNode());
                          },
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
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          ),
                          onTap: () {
                            // Ensure keyboard appears when tapping the field
                            FocusScope.of(context).requestFocus(FocusNode());
                          },
                          onChanged: (value) {
                            setState(() {
                              _units[originalText] = value;
                              
                              // Find product with matching unit
                              final currentSuggestion = _selectedSuggestions[originalText];
                              if (currentSuggestion != null && value.trim().isNotEmpty) {
                                final suggestions = _getSuggestionsForItem(originalText);
                                
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
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Stock Action Selection (full width)
            _buildStockActionSelector(originalText, selectedSuggestion),
            
            const SizedBox(height: 8),
            
            const SizedBox(height: 6),
            
            // Scrollable suggestions section - use remaining space
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Source Product Selection at top of options box (only show if out of stock)
                      if (selectedSuggestion != null) ...[
                        Builder(
                          builder: (context) {
                            final stock = selectedSuggestion['stock'] as Map<String, dynamic>?;
                            final availableQuantity = (stock?['available_quantity'] as num?)?.toDouble() ?? 0.0;
                            final inStock = selectedSuggestion['in_stock'] as bool? ?? false;
                            final unlimitedStock = selectedSuggestion['unlimited_stock'] as bool? ?? false;
                            final stockAction = _stockActions[originalText] ?? 'reserve';
                            // Don't auto-enable source product if user chose 'no_reserve' (continue without alternatives)
                            if (!inStock && !unlimitedStock && availableQuantity <= 0 && stockAction != 'no_reserve') {
                              // Auto-enable source product when out of stock (unless user chose to continue)
                              if (_useSourceProduct[originalText] != true) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) {
                                    setState(() {
                                      _useSourceProduct[originalText] = true;
                                    });
                                  }
                                });
                              }
                              return Column(
                                children: [
                                  _buildSourceProductSelector(originalText, selectedSuggestion),
                                  const SizedBox(height: 12),
                                  const Divider(),
                                  const SizedBox(height: 12),
                                ],
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                      
                      // Suggestions list
                      suggestions.isEmpty
                          ? (_isSearching[originalText] == true)
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
                          : _buildSuggestionsList(suggestions, originalText),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSuggestionsList(List<dynamic> suggestions, String originalText) {
    // Ensure kg products are always included and prioritized
    final sortedSuggestions = _ensureKgProductsIncluded(suggestions);
    
    return Column(
      children: [
        // Selected suggestion - prominent display (shows the actually selected item)
        if (sortedSuggestions.isNotEmpty) ...[
          _buildProminentSuggestion(_selectedSuggestions[originalText] ?? sortedSuggestions.first, originalText, 0),
          if (sortedSuggestions.length > 1) ...[
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
        // Two-column grid layout for better navigation
        if (sortedSuggestions.length > 1)
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.2, // Adjust based on content height/width ratio
            children: sortedSuggestions.map<Widget>((suggestion) {
              return _buildCompactSuggestion(suggestion, originalText);
            }).toList(),
          ),
      ],
    );
  }
  
  // Ensure kg products are always included in suggestions, even if bag/packet/box versions exist
  List<dynamic> _ensureKgProductsIncluded(List<dynamic> suggestions) {
    if (suggestions.isEmpty) return suggestions;
    
    // Group suggestions by base product name (without packaging info)
    final Map<String, List<Map<String, dynamic>>> productGroups = {};
    final kgProducts = <Map<String, dynamic>>[];
    
    for (final suggestion in suggestions) {
      final productName = (suggestion['product_name'] as String? ?? '').toLowerCase();
      final unit = (suggestion['unit'] as String? ?? '').toLowerCase();
      
      // Extract base product name (remove packaging info)
      final baseName = productName
          .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
          .replaceAll(RegExp(r'\b(bag|packet|box|punnet|bunch|head|each)\b'), '')
          .trim();
      
      // Track kg products separately
      if (unit == 'kg') {
        kgProducts.add(Map<String, dynamic>.from(suggestion));
      }
      
      if (!productGroups.containsKey(baseName)) {
        productGroups[baseName] = [];
      }
      productGroups[baseName]!.add(Map<String, dynamic>.from(suggestion));
    }
    
    // Build final list ensuring kg products are included
    final result = <Map<String, dynamic>>[];
    final addedProductIds = <int>{};
    
    // First, add all kg products (they should always be shown)
    for (final kgProduct in kgProducts) {
      final productId = kgProduct['product_id'] as int?;
      if (productId != null && !addedProductIds.contains(productId)) {
        result.add(kgProduct);
        addedProductIds.add(productId);
      }
    }
    
    // Then add all other suggestions
    for (final suggestion in suggestions) {
      final productId = suggestion['product_id'] as int?;
      if (productId != null && !addedProductIds.contains(productId)) {
        result.add(Map<String, dynamic>.from(suggestion));
        addedProductIds.add(productId);
      }
    }
    
    // Sort to prioritize kg products at the top
    result.sort((a, b) {
      final aUnit = (a['unit'] as String? ?? '').toLowerCase();
      final bUnit = (b['unit'] as String? ?? '').toLowerCase();
      final aIsKg = aUnit == 'kg';
      final bIsKg = bUnit == 'kg';
      
      // Kg products first
      if (aIsKg != bIsKg) {
        return aIsKg ? -1 : 1;
      }
      
      // Then by confidence score
      final aScore = (a['confidence_score'] as num?)?.toDouble() ?? 0.0;
      final bScore = (b['confidence_score'] as num?)?.toDouble() ?? 0.0;
      if (aScore != bScore) {
        return bScore.compareTo(aScore);
      }
      
      // Finally by stock availability
      final aInStock = a['in_stock'] as bool? ?? false;
      final bInStock = b['in_stock'] as bool? ?? false;
      if (aInStock != bInStock) {
        return bInStock ? 1 : -1;
      }
      
      return 0;
    });
    
    return result;
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
        // Always show modal for product selection
        _showProductSelectionModal(originalText, suggestion);
      },
      behavior: HitTestBehavior.opaque,
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
                // RECOMMENDED badge commented out - two-column layout makes it unnecessary
                // Container(
                //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                //   decoration: BoxDecoration(
                //     color: useSource && isSourceSelected
                //         ? Colors.amber
                //         : useSource && !hasStock
                //             ? Colors.grey
                //             : isSelected 
                //                 ? Colors.green 
                //                 : Colors.blue,
                //     borderRadius: BorderRadius.circular(10),
                //   ),
                //   child: Text(
                //     useSource && isSourceSelected
                //         ? 'SOURCE'
                //         : useSource && !hasStock
                //             ? 'NO STOCK'
                //             : isSelected 
                //                 ? 'SELECTED' 
                //                 : 'RECOMMENDED',
                //     style: const TextStyle(
                //       color: Colors.white,
                //       fontSize: 9,
                //       fontWeight: FontWeight.bold,
                //     ),
                //   ),
                // ),
                // Show badges only for non-recommended states
                if (useSource && isSourceSelected || useSource && !hasStock || isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: useSource && isSourceSelected
                          ? Colors.amber
                          : useSource && !hasStock
                              ? Colors.grey
                              : Colors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      useSource && isSourceSelected
                          ? 'SOURCE'
                          : useSource && !hasStock
                              ? 'NO STOCK'
                              : 'SELECTED',
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
        // Always show modal for product selection
        _showProductSelectionModal(originalText, suggestion);
      },
      behavior: HitTestBehavior.opaque,
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

  /// Check if an item has been changed from its original state
  bool _isItemChanged(String originalText) {
    // Check if product selected
    if (_selectedSuggestions[originalText] != null) return true;
    
    // Check if skipped
    if (_skippedItems[originalText] == true) return true;
    
    // Check if original text edited
    if (_editedOriginalText[originalText] != originalText) return true;
    
    // Find the original item
    final originalItem = _items.firstWhere(
      (i) => i['original_text'] == originalText,
      orElse: () => <String, dynamic>{},
    );
    
    if (originalItem.isEmpty) return false;
    
    // Check if quantity changed from parsed
    final parsed = originalItem['parsed'] as Map<String, dynamic>? ?? {};
    final parsedQuantity = (parsed['quantity'] as num?)?.toDouble() ?? 1.0;
    final currentQuantity = _quantities[originalText] ?? parsedQuantity;
    if ((currentQuantity - parsedQuantity).abs() > 0.001) return true;
    
    // Check if unit changed from parsed
    final parsedUnit = parsed['unit'] as String? ?? 'each';
    final currentUnit = _units[originalText] ?? parsedUnit;
    if (currentUnit != parsedUnit) return true;
    
    // Check if stock action set (and not default 'reserve')
    final stockAction = _stockActions[originalText];
    if (stockAction != null && stockAction != 'reserve') return true;
    
    // Check if source product selected
    if (_selectedSourceProducts[originalText] != null) return true;
    
    return false;
  }

  Future<void> _saveProgress() async {
    try {
      // Filter only changed items
      final changedItems = <String>[];
      final unprocessedItems = <String>[];
      
      for (var item in _items) {
        final originalText = item['original_text'] as String;
        if (_isItemChanged(originalText)) {
          changedItems.add(originalText);
        } else {
          unprocessedItems.add(originalText);
        }
      }
      
      // Build filtered maps for changed items only
      final filteredSelectedSuggestions = <String, Map<String, dynamic>>{};
      final filteredQuantities = <String, double>{};
      final filteredUnits = <String, String>{};
      final filteredStockActions = <String, String>{};
      final filteredSkippedItems = <String, bool>{};
      final filteredUseSourceProduct = <String, bool>{};
      final filteredSelectedSourceProducts = <String, Map<String, dynamic>>{};
      final filteredSourceQuantities = <String, double>{};
      final filteredSourceQuantityUnits = <String, String>{};
      final filteredEditedOriginalText = <String, String>{};
      
      for (final originalText in changedItems) {
        if (_selectedSuggestions[originalText] != null) {
          filteredSelectedSuggestions[originalText] = _selectedSuggestions[originalText]!;
        }
        if (_quantities[originalText] != null) {
          filteredQuantities[originalText] = _quantities[originalText]!;
        }
        if (_units[originalText] != null) {
          filteredUnits[originalText] = _units[originalText]!;
        }
        if (_stockActions[originalText] != null) {
          filteredStockActions[originalText] = _stockActions[originalText]!;
        }
        if (_skippedItems[originalText] == true) {
          filteredSkippedItems[originalText] = true;
        }
        if (_useSourceProduct[originalText] == true) {
          filteredUseSourceProduct[originalText] = true;
        }
        if (_selectedSourceProducts[originalText] != null) {
          filteredSelectedSourceProducts[originalText] = _selectedSourceProducts[originalText]!;
        }
        if (_sourceQuantities[originalText] != null) {
          filteredSourceQuantities[originalText] = _sourceQuantities[originalText]!;
        }
        if (_sourceQuantityUnits[originalText] != null) {
          filteredSourceQuantityUnits[originalText] = _sourceQuantityUnits[originalText]!;
        }
        if (_editedOriginalText[originalText] != null && _editedOriginalText[originalText] != originalText) {
          filteredEditedOriginalText[originalText] = _editedOriginalText[originalText]!;
        }
      }
      
      await OrderItemsPersistence.saveProgress(
        messageId: widget.messageId,
        selectedSuggestions: filteredSelectedSuggestions,
        quantities: filteredQuantities,
        units: filteredUnits,
        stockActions: filteredStockActions,
        skippedItems: filteredSkippedItems,
        useSourceProduct: filteredUseSourceProduct,
        selectedSourceProducts: filteredSelectedSourceProducts,
        sourceQuantities: filteredSourceQuantities,
        sourceQuantityUnits: filteredSourceQuantityUnits,
        editedOriginalText: filteredEditedOriginalText,
        unprocessedItems: unprocessedItems,
        showSnackbar: true,
        context: context,
      );
    } catch (e) {
      print('[ORDER_ITEMS] Error saving progress: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving progress: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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
      
      for (var item in _items) {
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
              itemData['source_unit'] = sourceProduct['unit'] ?? 'each';
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
          final sourceQuantity = item['source_quantity'] ?? 0.0;
          final sourceUnit = item['source_unit'] ?? 'each';
          notes = 'Stock from: ${item['source_product_name']} (${sourceQuantity.toStringAsFixed(1)} $sourceUnit)';
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
      
      for (var item in _items) {
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
          // Check if product is out of stock
          final stock = selectedSuggestion['stock'] as Map<String, dynamic>?;
          final availableQuantity = (stock?['available_quantity'] as num?)?.toDouble() ?? 0.0;
          final inStock = selectedSuggestion['in_stock'] as bool? ?? false;
          final unlimitedStock = selectedSuggestion['unlimited_stock'] as bool? ?? false;
          final isOutOfStock = !inStock && !unlimitedStock && availableQuantity <= 0;
          
          // Determine stock action - if out of stock and no source product selected, use 'no_reserve'
          var stockAction = _stockActions[originalText] ?? 'reserve';
          if (isOutOfStock && (_useSourceProduct[originalText] != true || _selectedSourceProducts[originalText] == null)) {
            stockAction = 'no_reserve';
            // Clear source product flags since we're proceeding without one
            _useSourceProduct[originalText] = false;
            _selectedSourceProducts.remove(originalText);
            _sourceQuantities.remove(originalText);
            _sourceQuantityUnits.remove(originalText);
          }
          
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
          // Skip source product requirement if stock action is 'no_reserve' (user chose to continue without alternatives)
          // Only require source product if explicitly enabled AND user hasn't chosen to continue without alternatives
          if (_useSourceProduct[originalText] == true && stockAction != 'no_reserve') {
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
                    content: Text('Please select a source product for "${selectedSuggestion['product_name']}" or click "Continue" to order without stock'),
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
            itemData['source_unit'] = sourceProduct['unit'] ?? 'each';
          } else if (_useSourceProduct[originalText] == true && stockAction == 'no_reserve') {
            // User clicked Continue but _useSourceProduct is still true - clear it
            _useSourceProduct[originalText] = false;
            _selectedSourceProducts.remove(originalText);
            _sourceQuantities.remove(originalText);
            _sourceQuantityUnits.remove(originalText);
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
          
          // Clear saved progress since order is complete
          await OrderItemsPersistence.clearOrderProgress(widget.messageId);
          print('[ORDER_ITEMS] Cleared saved progress after order confirmation');
          
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

  Widget _buildStockActionSelector(String originalText, Map<String, dynamic>? selectedSuggestion, {VoidCallback? onChanged}) {
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
    final useSource = _useSourceProduct[originalText] ?? false;
    final selectedSourceProduct = _selectedSourceProducts[originalText];
    final sourceQuantity = _sourceQuantities[originalText];
    
    // If source product is selected, show green alert with reserved stock info instead of red alert
    if (!hasAvailableStock && useSource && selectedSourceProduct != null) {
      final hasQuantity = sourceQuantity != null && sourceQuantity > 0;
      final quantityText = hasQuantity 
          ? '${sourceQuantity.toStringAsFixed(1)} ${selectedSourceProduct['unit'] ?? ''}'
          : 'Select quantity';
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, size: 16, color: Colors.green.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasQuantity
                    ? '✅ Ready to go! Stock reserved: $quantityText from ${selectedSourceProduct['name']}'
                    : 'Source product selected: ${selectedSourceProduct['name']} - Enter quantity below',
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
    
    // Hide the no stock alert if source product is being used
    if (!hasAvailableStock && !(useSource && selectedSourceProduct != null)) {
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
    
    // If has stock, continue to show stock action selector below
    
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
      width: double.infinity, // Full width
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
          
          // Stock action options (full width)
          Row(
            children: [
              // Reserve stock option
              Expanded(
                child: _buildStockActionChip(
                  originalText,
                  'reserve',
                  'Reserve Stock',
                  Icons.lock,
                  Colors.green,
                  currentAction == 'reserve',
                  onChanged: onChanged,
                ),
              ),
              
              const SizedBox(width: 8),
              
              // No reserve option
              Expanded(
                child: _buildStockActionChip(
                  originalText,
                  'no_reserve',
                  'No Reserve',
                  Icons.lock_open,
                  Colors.orange,
                  currentAction == 'no_reserve',
                  onChanged: onChanged,
                ),
              ),
              
              // Flexible kg conversion option (only if applicable)
              if (canConvertToBulk) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStockActionChip(
                    originalText,
                    'convert_to_kg',
                    'Flexible Kg Conversion',
                    Icons.transform,
                    Colors.blue,
                    currentAction == 'convert_to_kg',
                    onChanged: onChanged,
                  ),
                ),
              ],
            ],
          ),
          
          // Show stock availability info
          const SizedBox(height: 4),
          Builder(
            builder: (context) {
              final stock = selectedSuggestion?['stock'] as Map<String, dynamic>?;
              final availableCount = (stock?['available_quantity_count'] as num?)?.toInt();
              final availableWeightKg = (stock?['available_quantity_kg'] as num?)?.toDouble();
              
              return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: inStock ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
                child: Builder(
                  builder: (context) {
                    // Build stock display - always show both count and weight if available
                    String stockDisplay = '';
                    if (availableCount != null && availableCount > 0) {
                      stockDisplay = availableCount.toString();
                      if (availableWeightKg != null && availableWeightKg > 0) {
                        stockDisplay += ' (${availableWeightKg.toStringAsFixed(1)} kg)';
                      }
                      stockDisplay += ' $unit';
                    } else if (availableWeightKg != null && availableWeightKg > 0) {
                      stockDisplay = '${availableWeightKg.toStringAsFixed(1)} kg';
                    } else {
                      stockDisplay = '0 $unit';
                    }
                    
                    return Text(
                      'Available: $stockDisplay',
                      style: TextStyle(
                        fontSize: 10,
                        color: inStock ? Colors.green.shade700 : Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
            ),
              );
            },
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
    final useSource = _useSourceProduct[originalText] ?? true; // Always true when shown (out of stock)
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
          // Header text
          Text(
            'Use stock from another product',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
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
          
          // Unit selector (head/kg toggle) - only show if packaging_size is available and source product is selected
          if (selectedSourceProduct != null) ...[
            Builder(
              builder: (context) {
                var packagingSize = selectedSourceProduct['packagingSize'] as String?;
                
                // Fallback: Try to extract from product name if packaging_size is missing
                if (packagingSize == null || packagingSize.isEmpty) {
                  final productName = selectedSourceProduct['name'] as String?;
                  packagingSize = PackagingSizeParser.extractFromProductName(productName);
                }
                
                final nativeUnit = selectedSourceProduct['unit'] as String? ?? 'each';
                final canUseKg = packagingSize != null && 
                               PackagingSizeParser.canCalculateWeight(packagingSize) &&
                               (nativeUnit.toLowerCase() == 'head' || 
                                nativeUnit.toLowerCase() == 'each' ||
                                nativeUnit.toLowerCase() == 'bunch');
                
                final currentInputUnit = _sourceQuantityUnits[originalText] ?? nativeUnit;
                
                if (canUseKg) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enter quantity in:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _sourceQuantityUnits[originalText] = nativeUnit;
                                  _sourceQuantities.remove(originalText);
                                  _sourceQuantityControllers[originalText]?.clear();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: currentInputUnit == nativeUnit 
                                      ? Colors.blue.withValues(alpha: 0.2)
                                      : Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: currentInputUnit == nativeUnit 
                                        ? Colors.blue.shade600
                                        : Colors.grey.withValues(alpha: 0.3),
                                    width: currentInputUnit == nativeUnit ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      currentInputUnit == nativeUnit ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                      size: 16,
                                      color: currentInputUnit == nativeUnit ? Colors.blue.shade700 : Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      nativeUnit,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: currentInputUnit == nativeUnit ? FontWeight.w600 : FontWeight.normal,
                                        color: currentInputUnit == nativeUnit ? Colors.blue.shade700 : Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _sourceQuantityUnits[originalText] = 'kg';
                                  _sourceQuantities.remove(originalText);
                                  _sourceQuantityControllers[originalText]?.clear();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: currentInputUnit == 'kg' 
                                      ? Colors.blue.withValues(alpha: 0.2)
                                      : Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: currentInputUnit == 'kg' 
                                        ? Colors.blue.shade600
                                        : Colors.grey.withValues(alpha: 0.3),
                                    width: currentInputUnit == 'kg' ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      currentInputUnit == 'kg' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                      size: 16,
                                      color: currentInputUnit == 'kg' ? Colors.blue.shade700 : Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'kg',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: currentInputUnit == 'kg' ? FontWeight.w600 : FontWeight.normal,
                                        color: currentInputUnit == 'kg' ? Colors.blue.shade700 : Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
          // Quantity input field
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              if (selectedSourceProduct == null) {
                return TextField(
                  controller: _sourceQuantityControllers[originalText],
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    labelText: 'Quantity to Deduct *',
                    labelStyle: TextStyle(fontSize: 11),
                    hintText: 'Select source product first',
                    helperText: 'Select a source product above first, then enter quantity',
                    helperMaxLines: 2,
                  ),
                  style: TextStyle(fontSize: 11),
                  enabled: false,
                );
              }
              
              final currentInputUnit = _sourceQuantityUnits[originalText] ?? selectedSourceProduct['unit'] ?? 'each';
              final isKgInput = currentInputUnit == 'kg';
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _sourceQuantityControllers[originalText],
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      labelText: 'Quantity to Deduct (${isKgInput ? 'kg' : selectedSourceProduct['unit'] ?? ''}) *',
                      labelStyle: TextStyle(fontSize: 11),
                      suffixText: isKgInput ? 'kg' : (selectedSourceProduct['unit'] as String? ?? ''),
                      hintText: isKgInput ? 'e.g., 5.0' : 'e.g., 5',
                      helperText: 'Required: Enter amount to deduct from ${selectedSourceProduct['name']}',
                      helperMaxLines: 2,
                      filled: true,
                      fillColor: Colors.amber.withValues(alpha: 0.05),
                    ),
                    style: TextStyle(fontSize: 11),
                    onTap: () {
                      // Ensure keyboard appears when tapping the field
                      FocusScope.of(context).requestFocus(FocusNode());
                    },
                    onChanged: (value) {
                      setState(() {
                        final inputValue = double.tryParse(value);
                        if (inputValue != null && inputValue > 0) {
                          if (isKgInput) {
                            // Convert kg to native unit (head/each/bunch)
                            final packagingSize = selectedSourceProduct['packagingSize'] as String?;
                            final weightPerUnitKg = PackagingSizeParser.parseToKg(packagingSize);
                            
                            if (weightPerUnitKg != null && weightPerUnitKg > 0) {
                              // Convert: kg entered / kg per unit = number of units
                              final convertedQuantity = inputValue / weightPerUnitKg;
                              _sourceQuantities[originalText] = convertedQuantity;
                            } else {
                              // Can't convert, remove quantity
                              _sourceQuantities.remove(originalText);
                            }
                          } else {
                            // Direct input in native unit
                            _sourceQuantities[originalText] = inputValue;
                          }
                        } else {
                          _sourceQuantities.remove(originalText);
                        }
                      });
                    },
                  ),
                  // Show conversion calculation if kg input
                  if (isKgInput) ...[
                    Builder(
                      builder: (context) {
                        final inputValue = double.tryParse(_sourceQuantityControllers[originalText]?.text ?? '');
                        final packagingSize = selectedSourceProduct['packagingSize'] as String?;
                        final weightPerUnitKg = PackagingSizeParser.parseToKg(packagingSize);
                        final nativeUnit = selectedSourceProduct['unit'] as String? ?? 'each';
                        
                        if (inputValue != null && inputValue > 0 && weightPerUnitKg != null && weightPerUnitKg > 0) {
                          final convertedQuantity = inputValue / weightPerUnitKg;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calculate, size: 14, color: Colors.blue.shade700),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${inputValue.toStringAsFixed(2)} kg = ${convertedQuantity.toStringAsFixed(2)} $nativeUnit (at ${weightPerUnitKg.toStringAsFixed(2)} kg per $nativeUnit)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ],
              );
            },
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
    bool isSelected, {
    VoidCallback? onChanged,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _stockActions[originalText] = action;
        });
        // Also trigger modal state update if callback provided
        onChanged?.call();
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
        // Show suggested missing descriptors button
        _buildMissingDescriptorSuggestions(originalText, currentSearchTerm),
      ],
    );
  }

  // Get suggested missing descriptors from product names (using database data)
  // Extracts descriptors from the FRONT of product names (supports 1-2 word descriptors)
  List<String> _getMissingDescriptors(String searchTerm, List<dynamic> suggestions) {
    // Validate input
    if (searchTerm.trim().isEmpty) return [];
    
    // Get all products from database to analyze common descriptors
    final productsState = ref.read(productsProvider);
    final allProducts = productsState.products;
    
    if (allProducts.isEmpty) return [];
    
    // Build set of common quantity/unit words from actual product units in database
    final unitWords = <String>{};
    final quantityPattern = RegExp(r'^\d+(\.\d+)?$');
    for (final product in allProducts) {
      if (product.unit != null) {
        unitWords.add(product.unit!.toLowerCase());
      }
    }
    // Add common quantity patterns
    unitWords.addAll({'kg', 'g', 'ml', 'l', 'box', 'bag', 'bunch', 'head', 
                      'each', 'packet', 'punnet', 'x', '×', '*', 'pcs', 'pieces'});
    
    // Extract words from search term (excluding quantity/unit words)
    final searchWords = searchTerm.toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !unitWords.contains(w.toLowerCase()) && !quantityPattern.hasMatch(w))
        .map((w) => w.toLowerCase())
        .toList();
    
    // Get the base product name (everything except potential descriptor words at front)
    // Try 1-word and 2-word descriptors
    final baseProductWords = searchWords.length > 2 ? searchWords.sublist(2) : 
                            searchWords.length > 1 ? searchWords.sublist(1) : searchWords;
    final baseProductName = baseProductWords.join(' ');
    
    // Common stop words (not product descriptors)
    final stopWords = {'the', 'and', 'or', 'for', 'with', 'from', 'that', 'this', 'of', 'in', 'on', 'at'};
    
    // Collect descriptors from the FRONT of product names (1-2 words)
    final descriptorCounts = <String, int>{};
    
    // Analyze suggestions first (most relevant)
    for (final suggestion in suggestions) {
      final productName = (suggestion['product_name'] as String? ?? '').toLowerCase();
      final productWords = productName
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty && 
                       !unitWords.contains(w.toLowerCase()) && 
                       !quantityPattern.hasMatch(w) &&
                       !stopWords.contains(w.toLowerCase()))
          .map((w) => w.toLowerCase().trim())
          .where((w) => w.isNotEmpty)
          .toList();
      
      if (productWords.isEmpty) continue;
      
      // Try 2-word descriptor first (e.g., "sun dried")
      if (productWords.length >= 3) {
        final twoWordDescriptor = '${productWords[0]} ${productWords[1]}';
        final productBaseWords = productWords.sublist(2);
        final productBaseName = productBaseWords.join(' ');
        
        // Check if base names match
        final baseMatches = baseProductName.isNotEmpty && 
            (productBaseName.contains(baseProductName) || baseProductName.contains(productBaseName));
        final hasSearchWord = baseProductWords.isEmpty || 
            productWords.any((pw) => baseProductWords.contains(pw));
        
        if ((baseMatches || hasSearchWord) && 
            !searchWords.contains(productWords[0]) && 
            !searchWords.contains(productWords[1])) {
          descriptorCounts[twoWordDescriptor] = (descriptorCounts[twoWordDescriptor] ?? 0) + 1;
        }
      }
      
      // Also try 1-word descriptor
      if (productWords.length >= 2) {
        final frontDescriptor = productWords.first;
        final productBaseWords = productWords.sublist(1);
        final productBaseName = productBaseWords.join(' ');
        
        // Check if base names match
        final baseMatches = baseProductName.isNotEmpty && 
            (productBaseName.contains(baseProductName) || baseProductName.contains(productBaseName));
        final hasSearchWord = baseProductWords.isEmpty || 
            productWords.any((pw) => baseProductWords.contains(pw));
        
        if ((baseMatches || hasSearchWord) && 
            frontDescriptor.length > 2 && 
            !searchWords.contains(frontDescriptor)) {
          descriptorCounts[frontDescriptor] = (descriptorCounts[frontDescriptor] ?? 0) + 1;
        }
      }
    }
    
    // Also analyze all products in database to find common front descriptors
    for (final product in allProducts) {
      final productName = product.name.toLowerCase();
      final productWords = productName
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty && 
                       !unitWords.contains(w.toLowerCase()) && 
                       !quantityPattern.hasMatch(w) &&
                       !stopWords.contains(w.toLowerCase()))
          .map((w) => w.toLowerCase().trim())
          .where((w) => w.isNotEmpty)
          .toList();
      
      if (productWords.isEmpty) continue;
      
      // Try 2-word descriptor first
      if (productWords.length >= 3) {
        final twoWordDescriptor = '${productWords[0]} ${productWords[1]}';
        final productBaseWords = productWords.sublist(2);
        
        // Check if product contains at least one search word (partial match)
        final hasSearchWord = baseProductWords.isEmpty || 
            productWords.any((pw) => baseProductWords.contains(pw));
        
        if (hasSearchWord && 
            !searchWords.contains(productWords[0]) && 
            !searchWords.contains(productWords[1])) {
          descriptorCounts[twoWordDescriptor] = (descriptorCounts[twoWordDescriptor] ?? 0) + 1;
        }
      }
      
      // Also try 1-word descriptor
      if (productWords.length >= 2) {
        final frontDescriptor = productWords.first;
        
        // Check if product contains at least one search word (partial match)
        final hasSearchWord = baseProductWords.isEmpty || 
            productWords.any((pw) => baseProductWords.contains(pw));
        
        if (hasSearchWord && 
            frontDescriptor.length > 2 && 
            !searchWords.contains(frontDescriptor)) {
          descriptorCounts[frontDescriptor] = (descriptorCounts[frontDescriptor] ?? 0) + 1;
        }
      }
    }
    
    // Return most common descriptors (appearing in at least 2 products)
    // Prioritize 2-word descriptors over 1-word
    final commonDescriptors = descriptorCounts.entries
        .where((e) => e.value >= 2)
        .toList()
      ..sort((a, b) {
        // Sort by: 2-word descriptors first, then by frequency
        final aIsTwoWord = a.key.contains(' ');
        final bIsTwoWord = b.key.contains(' ');
        if (aIsTwoWord != bIsTwoWord) {
          return aIsTwoWord ? -1 : 1;
        }
        return b.value.compareTo(a.value);
      });
    
    return commonDescriptors.take(3).map((e) => e.key).toList();
  }

  // Build missing descriptor suggestions widget
  Widget _buildMissingDescriptorSuggestions(String originalText, String currentSearchTerm) {
    final suggestions = _updatedSuggestions[originalText] ?? [];
    final missingDescriptors = _getMissingDescriptors(currentSearchTerm, suggestions);
    
    // Show if we have missing descriptors (even if no suggestions, we might find partial matches in DB)
    if (missingDescriptors.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          ...missingDescriptors.map((descriptor) {
            return ActionChip(
              avatar: const Icon(Icons.add, size: 14),
              label: Text('Add "$descriptor"'),
              onPressed: () => _addDescriptorToSearch(originalText, currentSearchTerm, descriptor),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              labelStyle: const TextStyle(fontSize: 11),
            );
          }),
        ],
      ),
    );
  }

  // Add descriptor to search term and re-run search
  // Replaces any existing front descriptor, or adds if none exists
  // Preserves all quantities and amounts (e.g., "3 5kg mushrooms" -> "3 5kg brown mushrooms")
  Future<void> _addDescriptorToSearch(String originalText, String currentSearchTerm, String descriptor) async {
    // Get all products from database to determine common units
    final productsState = ref.read(productsProvider);
    final allProducts = productsState.products;
    
    // Build set of unit words from actual product units in database
    final unitWords = <String>{};
    final quantityPattern = RegExp(r'^\d+(\.\d+)?$');
    final weightPattern = RegExp(r'^\d+(\.\d+)?(kg|g|ml|l)$', caseSensitive: false);
    
    for (final product in allProducts) {
      if (product.unit != null) {
        unitWords.add(product.unit!.toLowerCase());
      }
    }
    // Add common quantity patterns
    unitWords.addAll({'kg', 'g', 'ml', 'l', 'box', 'bag', 'bunch', 'head', 
                      'each', 'packet', 'punnet', 'x', '×', '*', 'pcs', 'pieces'});
    
    final words = currentSearchTerm.split(RegExp(r'\s+'));
    final prefixParts = <String>[]; // Quantities, amounts, units (all preserved at front)
    final productParts = <String>[]; // Product name words (descriptors + base name)
    
    // Separate quantity/unit/weight words from product name words
    // Keep going until we hit a non-quantity/unit word
    bool foundProductStart = false;
    for (final word in words) {
      if (!foundProductStart) {
        // Check if it's a quantity, weight, or unit
        if (quantityPattern.hasMatch(word) || 
            weightPattern.hasMatch(word) || 
            unitWords.contains(word.toLowerCase())) {
          prefixParts.add(word);
        } else {
          // First non-quantity word - this starts the product name
          foundProductStart = true;
          productParts.add(word);
        }
      } else {
        // Already found product start, add to product parts
        productParts.add(word);
      }
    }
    
    // Extract base product name (everything except potential descriptor words at front)
    // Smart detection: check if first 1-2 words match known descriptors from database
    String baseProductName;
    if (productParts.isNotEmpty) {
      // Get all known descriptors from database to check against
      // Only consider words that appear as descriptors in products with 2+ words
      final allDescriptors = <String>{};
      for (final product in allProducts) {
        final productName = product.name.toLowerCase();
        final productWords = productName
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty && 
                         !unitWords.contains(w.toLowerCase()) && 
                         !quantityPattern.hasMatch(w))
            .toList();
        
        // Only add as descriptor if product has 2+ words (descriptor + base name)
        if (productWords.length >= 2) {
          // Add 1-word descriptor (first word when there are 2+ words total)
          allDescriptors.add(productWords.first);
        }
        if (productWords.length >= 3) {
          // Add 2-word descriptor (first 2 words when there are 3+ words total)
          allDescriptors.add('${productWords[0]} ${productWords[1]}');
        }
      }
      
      // CRITICAL: If there's only one word, it's ALWAYS the base product name
      // We never remove it - we just add the descriptor before it
      if (productParts.length == 1) {
        baseProductName = productParts.first;
      } else if (productParts.length >= 3) {
        // Three or more words: check if first 2 words form a known descriptor
        final twoWordDescriptor = '${productParts[0]} ${productParts[1]}'.toLowerCase();
        if (allDescriptors.contains(twoWordDescriptor)) {
          // First 2 words are a known descriptor, remove them
          baseProductName = productParts.sublist(2).join(' ');
        } else {
          // Check if first word is a known descriptor
          final oneWordDescriptor = productParts[0].toLowerCase();
          if (allDescriptors.contains(oneWordDescriptor)) {
            // First word is a known descriptor, remove it
            baseProductName = productParts.sublist(1).join(' ');
          } else {
            // No known descriptor found, keep all words as base product name
            // This ensures we don't accidentally remove the product name
            baseProductName = productParts.join(' ');
          }
        }
      } else {
        // Exactly two words: check if first is a known descriptor
        final oneWordDescriptor = productParts[0].toLowerCase();
        if (allDescriptors.contains(oneWordDescriptor)) {
          // First word is a known descriptor, keep only the second word as base
          baseProductName = productParts.last;
        } else {
          // First word is NOT a known descriptor, so it's part of the product name
          // Keep both words as the base product name
          baseProductName = productParts.join(' ');
        }
      }
    } else {
      baseProductName = '';
    }
    
    // Build updated search term: preserved quantities/amounts + new descriptor + base product name
    final updatedSearchTerm = [
      ...prefixParts, // All quantities, amounts, units preserved at front
      descriptor,     // New descriptor (replaces old one if exists)
      baseProductName, // Base product name
    ].where((w) => w.isNotEmpty).join(' ');
    
    // Update the search controller
    final searchController = _unitControllers['${originalText}_search'];
    if (searchController != null) {
      searchController.text = updatedSearchTerm;
    }
    
    // Re-run search with updated term
    await _rerunSearch(originalText, updatedSearchTerm);
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
          
          // DISABLED: Automatic selection after search - users must manually select
          // Auto-select best suggestion if available
          // if (suggestions.isNotEmpty) {
          //   // Sort suggestions by confidence and stock availability
          //   final sortedSuggestions = List<Map<String, dynamic>>.from(suggestions);
          //   sortedSuggestions.sort((a, b) {
          //     // Handle confidence_score which might be int or double from backend
          //     final aScore = (a['confidence_score'] as num?)?.toDouble() ?? 0.0;
          //     final bScore = (b['confidence_score'] as num?)?.toDouble() ?? 0.0;
          //     final aInStock = a['in_stock'] as bool? ?? false;
          //     final bInStock = b['in_stock'] as bool? ?? false;
          //     
          //     if (aInStock != bInStock) {
          //       return bInStock ? 1 : -1;
          //     }
          //     return bScore.compareTo(aScore);
          //   });
          //   
          //   _selectedSuggestions[originalText] = sortedSuggestions.first;
          //   
          //   // Update unit and quantity to match selected product
          //   final selectedSuggestion = _selectedSuggestions[originalText];
          //   if (selectedSuggestion != null) {
          //     // Update unit
          //     final productUnit = selectedSuggestion['unit'] as String? ?? 'each';
          //     _units[originalText] = productUnit;
          //     _unitControllers[originalText]?.text = productUnit;
          //     
          //     // Update quantity if suggestion has a parsed quantity
          //     final suggestionQuantity = selectedSuggestion['quantity'] as num?;
          //     if (suggestionQuantity != null) {
          //       final newQuantity = suggestionQuantity.toDouble();
          //       _quantities[originalText] = newQuantity;
          //       // Update quantity controller to reflect the change (after setState to avoid rebuild issues)
          //       WidgetsBinding.instance.addPostFrameCallback((_) {
          //         final quantityController = _quantityControllers[originalText];
          //         if (quantityController != null && mounted) {
          //           quantityController.text = newQuantity == newQuantity.toInt() 
          //               ? newQuantity.toInt().toString() 
          //               : newQuantity.toString();
          //         }
          //       });
          //     }
          //     
          //     // Set stock action based on product
          //     final unlimitedStock = selectedSuggestion['unlimited_stock'] as bool? ?? false;
          //     if (unlimitedStock) {
          //       _stockActions[originalText] = 'no_reserve';
          //     } else {
          //       final inStock = selectedSuggestion['in_stock'] as bool? ?? false;
          //       _stockActions[originalText] = inStock ? 'reserve' : 'no_reserve';
          //     }
          //   }
          // }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${suggestions.length} suggestions for "$newSearchTerm"'),
            backgroundColor: suggestions.isNotEmpty ? Colors.green : Colors.orange,
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

  // Show product selection modal (similar to bulk stock take)
  Future<void> _showProductSelectionModal(
    String originalText,
    Map<String, dynamic> suggestion,
  ) async {
    final stock = suggestion['stock'] as Map<String, dynamic>?;
    final availableCount = (stock?['available_quantity_count'] as num?)?.toInt();
    final availableWeightKg = (stock?['available_quantity_kg'] as num?)?.toDouble();
    // Fallback to original available_quantity for backward compatibility
    final availableQuantity = availableCount != null || availableWeightKg != null
        ? ((availableCount ?? 0) > 0 || (availableWeightKg ?? 0) > 0)
        : ((stock?['available_quantity'] as num?)?.toDouble() ?? 0.0) > 0;
    final inStock = suggestion['in_stock'] as bool? ?? false;
    final unlimitedStock = suggestion['unlimited_stock'] as bool? ?? false;
    final hasStock = availableQuantity || inStock || unlimitedStock;
    
    // Check if there are in-stock alternatives if this product is out of stock
    final allSuggestions = _getSuggestionsForItem(originalText);
    final inStockAlternatives = allSuggestions.where((s) {
      final sStock = s['stock'] as Map<String, dynamic>?;
      // Check all stock fields: count, weight, and legacy available_quantity
      final sAvailableCount = (sStock?['available_quantity_count'] as num?)?.toInt();
      final sAvailableWeightKg = (sStock?['available_quantity_kg'] as num?)?.toDouble();
      final sAvailableQuantity = (sStock?['available_quantity'] as num?)?.toDouble() ?? 0.0;
      final sInStock = s['in_stock'] as bool? ?? false;
      final sUnlimitedStock = s['unlimited_stock'] as bool? ?? false;
      
      // Product has stock if any of these conditions are true:
      final hasStock = sInStock || 
                      sUnlimitedStock || 
                      (sAvailableCount != null && sAvailableCount > 0) ||
                      (sAvailableWeightKg != null && sAvailableWeightKg > 0) ||
                      sAvailableQuantity > 0;
      
      return hasStock && s['product_id'] != suggestion['product_id'];
    }).toList();
    
    // Check if this is a kg product with no stock, but has bag/packet variants available
    final productUnit = (suggestion['unit'] as String? ?? '').toLowerCase();
    final isKgProduct = productUnit == 'kg';
    
    if (!hasStock && isKgProduct) {
      // Look for bag/packet variants of the same product with stock
      final packageVariants = allSuggestions.where((s) {
        final sUnit = (s['unit'] as String? ?? '').toLowerCase();
        final sProductName = (s['product_name'] as String? ?? '').toLowerCase();
        final kgProductName = (suggestion['product_name'] as String? ?? '').toLowerCase();
        
        // Check if it's a package variant (bag, packet, box, etc.) of the same product
        final isPackageUnit = sUnit == 'bag' || sUnit == 'packet' || sUnit == 'box' || 
                             sUnit == 'punnet' || sUnit == 'each';
        
        // Check if product names match (remove packaging info for comparison)
        final baseProductName = kgProductName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
        final sBaseProductName = sProductName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
        final isSameProduct = baseProductName == sBaseProductName || 
                             sProductName.contains(baseProductName) ||
                             baseProductName.contains(sBaseProductName);
        
        if (!isPackageUnit || !isSameProduct) return false;
        
        // Check if this variant has stock
        final sStock = s['stock'] as Map<String, dynamic>?;
        final sAvailableCount = (sStock?['available_quantity_count'] as num?)?.toInt() ?? 0;
        final sAvailableWeightKg = (sStock?['available_quantity_kg'] as num?)?.toDouble() ?? 0.0;
        final sAvailableQuantity = (sStock?['available_quantity'] as num?)?.toDouble() ?? 0.0;
        final sInStock = s['in_stock'] as bool? ?? false;
        final sUnlimitedStock = s['unlimited_stock'] as bool? ?? false;
        
        final sHasStock = sInStock || 
                         sUnlimitedStock || 
                         sAvailableCount > 0 ||
                         sAvailableWeightKg > 0 ||
                         sAvailableQuantity > 0;
        
        // Check if it has packaging_size set (needed for breakdown)
        final sPackagingSize = s['packaging_size'] as String?;
        final hasPackagingSize = sPackagingSize != null && sPackagingSize.isNotEmpty;
        
        return sHasStock && hasPackagingSize;
      }).toList();
      
      if (packageVariants.isNotEmpty) {
        // Show breakdown confirmation dialog
        await _showBreakdownConfirmationDialog(
          originalText,
          suggestion,
          packageVariants.first,
        );
        return;
      }
    }
    
    // If out of stock and has alternatives, show the out-of-stock options modal
    if (!hasStock && inStockAlternatives.isNotEmpty) {
      await _showOutOfStockOptionsModal(originalText, suggestion, inStockAlternatives);
      return;
    }
    
    // Otherwise show the product selection modal
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: hasStock 
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasStock ? Icons.check_circle : Icons.warning,
                        color: hasStock ? Colors.green.shade600 : Colors.orange.shade600,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              suggestion['product_name'] ?? 'Unknown Product',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Builder(
                              builder: (context) {
                                if (!hasStock) {
                                  return const Text('Out of Stock');
                                }
                                if (unlimitedStock) {
                                  return const Text('🌱 Always Available');
                                }
                                final suggestionUnit = suggestion['unit'] ?? 'each';
                                
                                // Build stock display - always show both count and weight if available
                                String stockDisplay = '';
                                if (availableCount != null && availableCount > 0) {
                                  stockDisplay = availableCount.toString();
                                  if (availableWeightKg != null && availableWeightKg > 0) {
                                    stockDisplay += ' (${availableWeightKg.toStringAsFixed(1)} kg)';
                                  }
                                  stockDisplay += ' $suggestionUnit';
                                } else if (availableWeightKg != null && availableWeightKg > 0) {
                                  stockDisplay = '${availableWeightKg.toStringAsFixed(1)} kg';
                                } else {
                                  stockDisplay = '0 $suggestionUnit';
                                }
                                
                                return Text(
                                  'In Stock: $stockDisplay',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: hasStock ? Colors.green.shade700 : Colors.orange.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Details
                        _buildProductDetailRow('Price', 'R${(suggestion['price'] ?? 0.0).toStringAsFixed(2)}'),
                        _buildProductDetailRow('Unit', suggestion['unit'] ?? 'each'),
                        if (suggestion['department'] != null)
                          _buildProductDetailRow('Department', suggestion['department']),
                        if (suggestion['confidence_score'] != null)
                          _buildProductDetailRow(
                            'Match Confidence',
                            '${(((suggestion['confidence_score'] as num?)?.toDouble() ?? 0.0) * 100).toStringAsFixed(0)}%',
                          ),
                        
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 20),
                        
                        // Quantity and Unit Selection
                        Text(
                          'Quantity & Unit',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _quantityControllers[originalText] ??= TextEditingController(
                                  text: (suggestion['quantity'] as num?)?.toString() ?? 
                                        _quantities[originalText]?.toString() ?? '1',
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Quantity',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                ),
                                onTap: () {
                                  // Ensure keyboard appears when tapping the field
                                  FocusScope.of(context).requestFocus(FocusNode());
                                  Future.delayed(const Duration(milliseconds: 100), () {
                                    _quantityControllers[originalText]?.selection = TextSelection.fromPosition(
                                      TextPosition(offset: _quantityControllers[originalText]!.text.length),
                                    );
                                  });
                                },
                                onChanged: (value) {
                                  final qty = double.tryParse(value);
                                  if (qty != null && qty > 0) {
                                    setModalState(() {
                                      _quantities[originalText] = qty;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Builder(
                                builder: (context) {
                                  // Always use suggestion's unit when modal opens, unless user has manually changed it
                                  final suggestionUnit = suggestion['unit']?.toString().trim();
                                  final unitController = _unitControllers[originalText];
                                  
                                  // Initialize or update controller with suggestion's unit
                                  if (unitController == null) {
                                    // Create new controller with suggestion's unit
                                    _unitControllers[originalText] = TextEditingController(
                                      text: suggestionUnit ?? _units[originalText] ?? 'each',
                                    );
                                    // Update _units map to match
                                    if (suggestionUnit != null) {
                                      _units[originalText] = suggestionUnit;
                                    }
                                  } else {
                                    // Update existing controller if suggestion has a unit and it's different
                                    if (suggestionUnit != null && unitController.text != suggestionUnit) {
                                      unitController.text = suggestionUnit;
                                      _units[originalText] = suggestionUnit;
                                    }
                                  }
                                  
                                  return TextField(
                                    controller: _unitControllers[originalText]!,
                                    decoration: InputDecoration(
                                      labelText: 'Unit',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                    ),
                                    onTap: () {
                                      // Ensure keyboard appears when tapping the field
                                      FocusScope.of(context).requestFocus(FocusNode());
                                      Future.delayed(const Duration(milliseconds: 100), () {
                                        _unitControllers[originalText]?.selection = TextSelection.fromPosition(
                                          TextPosition(offset: _unitControllers[originalText]!.text.length),
                                        );
                                      });
                                    },
                                    onChanged: (value) {
                                      setModalState(() {
                                        _units[originalText] = value.trim();
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Stock Action (only if in stock)
                        if (hasStock) ...[
                          Text(
                            'Stock Action',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Builder(
                            builder: (context) => _buildStockActionSelector(originalText, suggestion, onChanged: () {
                              setModalState(() {});
                            }),
                          ),
                        ],
                        
                        // Out of stock message
                        if (!hasStock) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.orange.shade700),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'This product is out of stock. You can still add it without reserving stock.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                // Actions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _selectedSuggestions[originalText] = suggestion;
                            _selectedSourceProducts.remove(originalText);
                            _useSourceProduct[originalText] = false;
                            _sourceQuantities.remove(originalText);
                            _sourceQuantityUnits.remove(originalText);
                            _sourceQuantityControllers[originalText]?.clear();
                            
                            // Use values from modal
                            final qty = _quantities[originalText] ?? 
                                       (suggestion['quantity'] as num?)?.toDouble() ?? 1.0;
                            // Prioritize suggestion's unit if user hasn't manually changed it
                            // If unit controller exists and was modified, use that; otherwise use suggestion's unit
                            final unitController = _unitControllers[originalText];
                            final unitFromController = unitController?.text.trim();
                            final unitFromSuggestion = suggestion['unit']?.toString().trim();
                            final unit = (unitFromController != null && unitFromController.isNotEmpty && unitFromController != unitFromSuggestion)
                                ? unitFromController  // User manually changed it
                                : (unitFromSuggestion ?? _units[originalText] ?? 'each');  // Use suggestion's unit or existing
                            
                            _quantities[originalText] = qty;
                            _units[originalText] = unit;
                            
                            // Update unit controller to match final unit
                            if (unitController != null) {
                              unitController.text = unit;
                            }
                            
                            // Preserve user's stock action selection from modal, or set default if not set
                            // Only override if stock action wasn't already set by user in the modal
                            if (!_stockActions.containsKey(originalText)) {
                              if (unlimitedStock) {
                                _stockActions[originalText] = 'no_reserve';
                              } else if (hasStock) {
                                _stockActions[originalText] = 'reserve';
                              } else {
                                _stockActions[originalText] = 'no_reserve';
                              }
                            }
                            // If stock action was already set (by user clicking in modal), keep it
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 20),
                            SizedBox(width: 8),
                            Text('Confirm Selection'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildProductDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Show confirmation dialog for breaking down a bag/packet into kg
  Future<void> _showBreakdownConfirmationDialog(
    String originalText,
    Map<String, dynamic> kgProduct,
    Map<String, dynamic> packageProduct,
  ) async {
    final packageProductName = packageProduct['product_name'] as String? ?? 'Unknown';
    final packageUnit = packageProduct['unit'] as String? ?? '';
    final packageStock = packageProduct['stock'] as Map<String, dynamic>?;
    final packageAvailableCount = (packageStock?['available_quantity_count'] as num?)?.toInt() ?? 0;
    final packagePackagingSize = packageProduct['packaging_size'] as String?;
    
    // Calculate weight per package
    final weightPerPackageKg = PackagingSizeParser.parseToKg(packagePackagingSize);
    
    if (weightPerPackageKg == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot break down package: packaging size not set'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final kgProductName = kgProduct['product_name'] as String? ?? 'Unknown';
    final kgProductId = kgProduct['product_id'] as int?;
    final packageProductId = packageProduct['product_id'] as int?;
    
    if (kgProductId == null || packageProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid product IDs'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Break Down Package?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You need kg stock for "$kgProductName", but only $packageProductName ($packageUnit) is available.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              'Would you like to break down 1 $packageUnit to add ${weightPerPackageKg.toStringAsFixed(1)} kg to "$kgProductName"?',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Available: $packageAvailableCount $packageUnit',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Break Down'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      try {
        final apiService = ref.read(apiServiceProvider);
        final result = await apiService.breakDownPackageToKg(
          packageProductId: packageProductId,
          kgProductId: kgProductId,
          quantity: 1,
        );
        
        // Close loading dialog
        if (mounted) Navigator.of(context).pop();
        
        if (result['status'] == 'success' && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] as String? ?? 'Package broken down successfully'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Reload suggestions for this item
          await _rerunSearch(originalText, _editedOriginalText[originalText] ?? originalText);
        } else {
          throw Exception(result['error'] as String? ?? 'Unknown error');
        }
      } catch (e) {
        // Close loading dialog if still open
        if (mounted) Navigator.of(context).pop();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to break down package: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Show modal with in-stock alternatives and source product option
  Future<void> _showOutOfStockOptionsModal(
    String originalText,
    Map<String, dynamic> outOfStockSuggestion,
    List<dynamic> inStockAlternatives,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Out of Stock',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${outOfStockSuggestion['product_name']} is out of stock. Choose an option:',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Stock may need to be ordered. You can continue to add this item without reserving stock.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // In-stock alternatives
              if (inStockAlternatives.isNotEmpty) ...[
                // Non-clickable header - just informational text
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'In-Stock Alternatives:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                  ),
                ),
                ...inStockAlternatives.map((alt) {
                  final altStock = alt['stock'] as Map<String, dynamic>?;
                  final altAvailableCount = (altStock?['available_quantity_count'] as num?)?.toInt();
                  final altAvailableWeightKg = (altStock?['available_quantity_kg'] as num?)?.toDouble();
                  final altInStock = alt['in_stock'] as bool? ?? false;
                  final altUnlimitedStock = alt['unlimited_stock'] as bool? ?? false;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedSuggestions[originalText] = alt;
                          _selectedSourceProducts.remove(originalText);
                          _useSourceProduct[originalText] = false;
                          _sourceQuantities.remove(originalText);
                          _sourceQuantityUnits.remove(originalText);
                          _sourceQuantityControllers[originalText]?.clear();
                          
                          final newUnit = alt['unit'] as String? ?? 'each';
                          _units[originalText] = newUnit;
                          
                          final suggestionQuantity = alt['quantity'] as num?;
                          if (suggestionQuantity != null) {
                            _quantities[originalText] = suggestionQuantity.toDouble();
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alt['product_name'] ?? 'Unknown',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Builder(
                                    builder: (context) {
                                      if (altUnlimitedStock) {
                                        return const Text('🌱 Always Available');
                                      }
                                      final altUnit = alt['unit'] ?? 'each';
                                      final unitLower = altUnit.toLowerCase();
                                      
                                      // Build stock display - always show both count and weight if available
                                      String stockDisplay = '';
                                      if (altAvailableCount != null && altAvailableCount > 0) {
                                        stockDisplay = altAvailableCount.toString();
                                        if (altAvailableWeightKg != null && altAvailableWeightKg > 0) {
                                          stockDisplay += ' (${altAvailableWeightKg.toStringAsFixed(1)} kg)';
                                        }
                                        stockDisplay += ' $altUnit';
                                      } else if (altAvailableWeightKg != null && altAvailableWeightKg > 0) {
                                        stockDisplay = '${altAvailableWeightKg.toStringAsFixed(1)} kg';
                                      } else {
                                        stockDisplay = '0 $altUnit';
                                      }
                                      
                                      return Text(
                                        'Stock: $stockDisplay',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'R${(alt['price'] ?? 0.0).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
              ],
              
              // Use stock from another product option
              // Non-clickable header - just informational text
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Or use stock from another product:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                ),
              ),
              
              // Show all suggestions with stock for source product selection
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Select a source product:',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
              ),
              
              // List of all suggestions with stock (for source product selection)
              Builder(
                builder: (context) {
                  final allSuggestions = _getSuggestionsForItem(originalText);
                  final productsWithStock = allSuggestions.where((s) {
                    final sStock = s['stock'] as Map<String, dynamic>?;
                    // Check all stock fields: count, weight, and legacy available_quantity
                    final sAvailableCount = (sStock?['available_quantity_count'] as num?)?.toInt();
                    final sAvailableWeightKg = (sStock?['available_quantity_kg'] as num?)?.toDouble();
                    final sAvailableQuantity = (sStock?['available_quantity'] as num?)?.toDouble() ?? 0.0;
                    final sInStock = s['in_stock'] as bool? ?? false;
                    final sUnlimitedStock = s['unlimited_stock'] as bool? ?? false;
                    
                    // Product has stock if any of these conditions are true:
                    return sInStock || 
                           sUnlimitedStock || 
                           (sAvailableCount != null && sAvailableCount > 0) ||
                           (sAvailableWeightKg != null && sAvailableWeightKg > 0) ||
                           sAvailableQuantity > 0;
                  }).toList();
                  
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: productsWithStock.length,
                      itemBuilder: (context, index) {
                        final sourceSuggestion = productsWithStock[index];
                        final sourceStock = sourceSuggestion['stock'] as Map<String, dynamic>?;
                        final sourceAvailableCount = (sourceStock?['available_quantity_count'] as num?)?.toInt();
                        final sourceAvailableWeightKg = (sourceStock?['available_quantity_kg'] as num?)?.toDouble();
                        // Fallback for backward compatibility
                        final sourceAvailableQuantity = sourceAvailableCount != null || sourceAvailableWeightKg != null
                            ? ((sourceAvailableCount ?? 0) > 0 || (sourceAvailableWeightKg ?? 0) > 0)
                            : ((sourceStock?['available_quantity'] as num?)?.toDouble() ?? 0.0) > 0;
                        final sourceInStock = sourceSuggestion['in_stock'] as bool? ?? false;
                        final sourceUnlimitedStock = sourceSuggestion['unlimited_stock'] as bool? ?? false;
                        final sourceProductId = sourceSuggestion['product_id'] as int?;
                        final currentSourceProduct = _selectedSourceProducts[originalText];
                        final isSourceSelected = currentSourceProduct != null && currentSourceProduct['id'] == sourceProductId;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: InkWell(
                            onTap: () {
                              setModalState(() {
                                final packagingSize = sourceSuggestion['packaging_size'] as String?;
                                print('[SOURCE PRODUCT SELECT] Product: ${sourceSuggestion['product_name']}, Unit: ${sourceSuggestion['unit']}, PackagingSize: $packagingSize');
                                print('[SOURCE PRODUCT SELECT] Full suggestion keys: ${sourceSuggestion.keys.toList()}');
                                
                                _selectedSourceProducts[originalText] = {
                                  'id': sourceProductId,
                                  'name': sourceSuggestion['product_name'] ?? '',
                                  'unit': sourceSuggestion['unit'] ?? '',
                                  'packagingSize': packagingSize,
                                  'stockLevel': (sourceAvailableCount ?? 0) > 0 ? sourceAvailableCount : (sourceAvailableWeightKg ?? 0.0),
                                  'availableCount': sourceAvailableCount,
                                  'availableWeightKg': sourceAvailableWeightKg,
                                };
                                print('[SOURCE PRODUCT SELECT] Stored packagingSize: ${_selectedSourceProducts[originalText]?['packagingSize']}');
                                _useSourceProduct[originalText] = true;
                                // Reset quantity unit to native unit when selecting new source product
                                _sourceQuantityUnits[originalText] = sourceSuggestion['unit'] ?? 'each';
                                // Clear previous quantity
                                _sourceQuantities.remove(originalText);
                                _sourceQuantityControllers[originalText]?.clear();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSourceSelected 
                                    ? Colors.amber.withValues(alpha: 0.3)
                                    : Colors.grey.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSourceSelected 
                                      ? Colors.amber.shade600
                                      : Colors.grey.withValues(alpha: 0.2),
                                  width: isSourceSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSourceSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                    color: isSourceSelected ? Colors.amber.shade700 : Colors.grey,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sourceSuggestion['product_name'] ?? 'Unknown',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isSourceSelected ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                        Builder(
                                          builder: (context) {
                                            if (sourceUnlimitedStock) {
                                              return const Text('🌱 Always Available');
                                            }
                                            final sourceUnit = sourceSuggestion['unit'] ?? 'each';
                                            final unitLower = sourceUnit.toLowerCase();
                                            
                                            // Build stock display - always show both count and weight if available
                                            String stockDisplay = '';
                                            if (sourceAvailableCount != null && sourceAvailableCount > 0) {
                                              stockDisplay = sourceAvailableCount.toString();
                                              if (sourceAvailableWeightKg != null && sourceAvailableWeightKg > 0) {
                                                stockDisplay += ' (${sourceAvailableWeightKg.toStringAsFixed(1)} kg)';
                                              }
                                              stockDisplay += ' $sourceUnit';
                                            } else if (sourceAvailableWeightKg != null && sourceAvailableWeightKg > 0) {
                                              stockDisplay = '${sourceAvailableWeightKg.toStringAsFixed(1)} kg';
                                            } else {
                                              stockDisplay = '0 $sourceUnit';
                                            }
                                            
                                            return Text(
                                              'Stock: $stockDisplay',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.grey[600],
                                          ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 12),
              
              // Quantity field - always show when in "use stock from another product" section
              // Show placeholder/hint when no source product selected, full field when selected
              Builder(
                builder: (context) {
                  final selectedSourceProduct = _selectedSourceProducts[originalText];
                  final hasSourceProduct = selectedSourceProduct != null;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!hasSourceProduct) ...[
                        // Show hint when no source product selected
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Select a source product above, then enter quantity to deduct',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (hasSourceProduct) ...[
                        // Unit selector (head/kg toggle) - only show if packaging_size is available
                        Builder(
                          builder: (context) {
                            var packagingSize = selectedSourceProduct['packagingSize'] as String?;
                            
                            // Fallback: Try to extract from product name if packaging_size is missing
                            if (packagingSize == null || packagingSize.isEmpty) {
                              final productName = selectedSourceProduct['name'] as String?;
                              packagingSize = PackagingSizeParser.extractFromProductName(productName);
                            }
                            
                            final nativeUnit = selectedSourceProduct['unit'] as String? ?? 'each';
                            final canUseKg = packagingSize != null && 
                                           PackagingSizeParser.canCalculateWeight(packagingSize) &&
                                           (nativeUnit.toLowerCase() == 'head' || 
                                            nativeUnit.toLowerCase() == 'each' ||
                                            nativeUnit.toLowerCase() == 'bunch');
                            
                            final currentInputUnit = _sourceQuantityUnits[originalText] ?? nativeUnit;
                            
                            if (canUseKg) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Enter quantity in:',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () {
                                            setModalState(() {
                                              _sourceQuantityUnits[originalText] = nativeUnit;
                                              _sourceQuantities.remove(originalText);
                                              _sourceQuantityControllers[originalText]?.clear();
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: currentInputUnit == nativeUnit 
                                                  ? Colors.blue.withValues(alpha: 0.2)
                                                  : Colors.grey.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: currentInputUnit == nativeUnit 
                                                    ? Colors.blue.shade600
                                                    : Colors.grey.withValues(alpha: 0.3),
                                                width: currentInputUnit == nativeUnit ? 2 : 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  currentInputUnit == nativeUnit ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                                  size: 16,
                                                  color: currentInputUnit == nativeUnit ? Colors.blue.shade700 : Colors.grey,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  nativeUnit,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: currentInputUnit == nativeUnit ? FontWeight.w600 : FontWeight.normal,
                                                    color: currentInputUnit == nativeUnit ? Colors.blue.shade700 : Colors.grey[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () {
                                            setModalState(() {
                                              _sourceQuantityUnits[originalText] = 'kg';
                                              _sourceQuantities.remove(originalText);
                                              _sourceQuantityControllers[originalText]?.clear();
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: currentInputUnit == 'kg' 
                                                  ? Colors.blue.withValues(alpha: 0.2)
                                                  : Colors.grey.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: currentInputUnit == 'kg' 
                                                    ? Colors.blue.shade600
                                                    : Colors.grey.withValues(alpha: 0.3),
                                                width: currentInputUnit == 'kg' ? 2 : 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  currentInputUnit == 'kg' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                                  size: 16,
                                                  color: currentInputUnit == 'kg' ? Colors.blue.shade700 : Colors.grey,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'kg',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: currentInputUnit == 'kg' ? FontWeight.w600 : FontWeight.normal,
                                                    color: currentInputUnit == 'kg' ? Colors.blue.shade700 : Colors.grey[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        // Quantity input field
                        Builder(
                          builder: (context) {
                            final currentInputUnit = _sourceQuantityUnits[originalText] ?? selectedSourceProduct['unit'] ?? 'each';
                            final isKgInput = currentInputUnit == 'kg';
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _sourceQuantityControllers[originalText] ??= TextEditingController(),
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    labelText: 'Quantity to Deduct (${isKgInput ? 'kg' : selectedSourceProduct['unit'] ?? ''}) *',
                                    labelStyle: TextStyle(fontSize: 11),
                                    suffixText: isKgInput ? 'kg' : (selectedSourceProduct['unit'] as String? ?? ''),
                                    hintText: isKgInput ? 'e.g., 5.0' : 'e.g., 5',
                                    helperText: 'Enter amount to deduct from ${selectedSourceProduct['name'] ?? 'source product'}',
                                    helperMaxLines: 2,
                                    filled: true,
                                    fillColor: Colors.amber.withValues(alpha: 0.05),
                                  ),
                                  style: TextStyle(fontSize: 11),
                                  autofocus: false,
                                  onChanged: (value) {
                                    // Re-read current input unit inside callback to ensure we have latest value
                                    final currentUnit = _sourceQuantityUnits[originalText] ?? selectedSourceProduct['unit'] ?? 'each';
                                    final isKg = currentUnit == 'kg';
                                    
                                    final inputValue = double.tryParse(value);
                                    
                                    setModalState(() {
                                      if (inputValue != null && inputValue > 0) {
                                        if (isKg) {
                                          // Convert kg to native unit (head/each/bunch)
                                          var packagingSize = selectedSourceProduct['packagingSize'] as String?;
                                          
                                          // Fallback: Try to extract from product name if packaging_size is missing
                                          if (packagingSize == null || packagingSize.isEmpty) {
                                            final productName = selectedSourceProduct['name'] as String?;
                                            packagingSize = PackagingSizeParser.extractFromProductName(productName);
                                            print('[SOURCE PRODUCT CONVERT] Extracted packaging size from name: "$packagingSize" (from "$productName")');
                                          }
                                          
                                          print('[SOURCE PRODUCT CONVERT] Input: $inputValue kg, PackagingSize: $packagingSize');
                                          
                                          final weightPerUnitKg = PackagingSizeParser.parseToKg(packagingSize);
                                          print('[SOURCE PRODUCT CONVERT] Parsed weightPerUnitKg: $weightPerUnitKg');
                                          
                                          if (weightPerUnitKg != null && weightPerUnitKg > 0) {
                                            // Convert: kg entered / kg per unit = number of units
                                            final convertedQuantity = inputValue / weightPerUnitKg;
                                            _sourceQuantities[originalText] = convertedQuantity;
                                            print('[SOURCE PRODUCT] ✅ Converted $inputValue kg to $convertedQuantity ${selectedSourceProduct['unit']} (${weightPerUnitKg} kg per unit)');
                                          } else {
                                            // Can't convert, remove quantity
                                            _sourceQuantities.remove(originalText);
                                            print('[SOURCE PRODUCT] ❌ Cannot convert - packaging size: "$packagingSize", parsed: $weightPerUnitKg');
                                          }
                                        } else {
                                          // Direct input in native unit
                                          _sourceQuantities[originalText] = inputValue;
                                          print('[SOURCE PRODUCT] Direct input: $inputValue ${selectedSourceProduct['unit']}');
                                        }
                                      } else {
                                        _sourceQuantities.remove(originalText);
                                      }
                                    });
                                  },
                                ),
                                // Show conversion calculation if kg input
                                if (isKgInput) ...[
                                  Builder(
                                    builder: (context) {
                                      final inputValue = double.tryParse(_sourceQuantityControllers[originalText]?.text ?? '');
                                      final packagingSize = selectedSourceProduct['packagingSize'] as String?;
                                      final weightPerUnitKg = PackagingSizeParser.parseToKg(packagingSize);
                                      final nativeUnit = selectedSourceProduct['unit'] as String? ?? 'each';
                                      
                                      if (inputValue != null && inputValue > 0 && weightPerUnitKg != null && weightPerUnitKg > 0) {
                                        final convertedQuantity = inputValue / weightPerUnitKg;
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.calculate, size: 14, color: Colors.blue.shade700),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    '${inputValue.toStringAsFixed(2)} kg = ${convertedQuantity.toStringAsFixed(2)} $nativeUnit (at ${weightPerUnitKg.toStringAsFixed(2)} kg per $nativeUnit)',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.blue.shade700,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          // Continue button - always enabled, allows proceeding with out-of-stock product
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                // Set the out-of-stock product as selected
                _selectedSuggestions[originalText] = outOfStockSuggestion;
                // Clear source product settings (user chose to continue without alternatives)
                _selectedSourceProducts.remove(originalText);
                _useSourceProduct[originalText] = false;
                _sourceQuantities.remove(originalText);
                _sourceQuantityUnits.remove(originalText);
                _sourceQuantityControllers[originalText]?.clear();
                
                final newUnit = outOfStockSuggestion['unit'] as String? ?? 'each';
                _units[originalText] = newUnit;
                
                final suggestionQuantity = outOfStockSuggestion['quantity'] as num?;
                if (suggestionQuantity != null) {
                  _quantities[originalText] = suggestionQuantity.toDouble();
                }
                
                // Set stock action to 'no_reserve' - stock will need to be ordered
                _stockActions[originalText] = 'no_reserve';
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange.shade700,
              side: BorderSide(color: Colors.orange.shade700),
            ),
            child: const Text('Continue'),
          ),
          // Use StatefulBuilder's setModalState to ensure button rebuilds when quantity changes
          StatefulBuilder(
            builder: (context, setButtonState) {
              // Force rebuild by reading current values
              final hasSourceProduct = _selectedSourceProducts[originalText] != null;
              final sourceQuantity = _sourceQuantities[originalText];
              final hasSourceQuantity = sourceQuantity != null && sourceQuantity > 0;
              
              // Also check controller text as fallback for immediate feedback
              final controllerText = _sourceQuantityControllers[originalText]?.text ?? '';
              final inputValue = double.tryParse(controllerText);
              final hasValidInput = inputValue != null && inputValue > 0;
              
              // Button is enabled if we have source product AND (stored quantity OR valid input)
              final isEnabled = hasSourceProduct && (hasSourceQuantity || hasValidInput);
              
              print('[USE SOURCE BUTTON] hasSourceProduct=$hasSourceProduct, sourceQuantity=$sourceQuantity, hasSourceQuantity=$hasSourceQuantity, inputValue=$inputValue, isEnabled=$isEnabled');
              
              return ElevatedButton(
                onPressed: isEnabled ? () {
                  // Ensure quantity is set if we only have input value
                  if (!hasSourceQuantity && hasValidInput) {
                    final currentUnit = _sourceQuantityUnits[originalText] ?? _selectedSourceProducts[originalText]?['unit'] ?? 'each';
                    final isKg = currentUnit == 'kg';
                    
                    if (isKg) {
                      final packagingSize = _selectedSourceProducts[originalText]?['packagingSize'] as String?;
                      final weightPerUnitKg = PackagingSizeParser.parseToKg(packagingSize);
                      if (weightPerUnitKg != null && weightPerUnitKg > 0) {
                        _sourceQuantities[originalText] = inputValue! / weightPerUnitKg;
                      }
                    } else {
                      _sourceQuantities[originalText] = inputValue!;
                    }
                  }
                  
                  Navigator.pop(context);
                  setState(() {
                    // Set the out-of-stock product as selected
                    _selectedSuggestions[originalText] = outOfStockSuggestion;
                    // Source product mode is already enabled
                    
                    final newUnit = outOfStockSuggestion['unit'] as String? ?? 'each';
                    _units[originalText] = newUnit;
                    
                    final suggestionQuantity = outOfStockSuggestion['quantity'] as num?;
                    if (suggestionQuantity != null) {
                      _quantities[originalText] = suggestionQuantity.toDouble();
                    }
                  });
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEnabled 
                      ? Colors.amber.shade600 
                      : Colors.grey,
                ),
                child: const Text('Use Source Product'),
              );
            },
          ),
        ],
        ),
      ),
    );
  }
}

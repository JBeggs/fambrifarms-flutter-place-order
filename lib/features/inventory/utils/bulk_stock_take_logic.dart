import 'package:flutter/material.dart';
import '../../../models/product.dart';
import '../../../utils/packaging_size_parser.dart';

/// Business logic for bulk stock take operations
/// Handles entry building, validation, and data processing
class BulkStockTakeLogic {
  /// Build stock take entries from controllers and product data
  /// This is shared between preview and submit operations
  static List<Map<String, dynamic>> buildStockTakeEntries({
    required List<Product> stockTakeProducts,
    required Map<int, TextEditingController> controllers,
    required Map<int, TextEditingController> commentControllers,
    required Map<int, TextEditingController> wastageControllers,
    required Map<int, TextEditingController> wastageWeightControllers,
    required Map<int, TextEditingController> wastageReasonControllers,
    required Map<int, TextEditingController> weightControllers,
    required Map<int, double> originalStock,
  }) {
    final entries = <Map<String, dynamic>>[];
    
    // Process ALL product IDs that have any controller data
    final allProductIds = <int>{};
    allProductIds.addAll(controllers.keys);
    allProductIds.addAll(commentControllers.keys);
    allProductIds.addAll(wastageControllers.keys);
    allProductIds.addAll(stockTakeProducts.map((p) => p.id));
    
    for (final productId in allProductIds) {
      final product = stockTakeProducts.where((p) => p.id == productId).firstOrNull;
      
      final controller = controllers[productId];
      final commentController = commentControllers[productId];
      final wastageController = wastageControllers[productId];
      final wastageWeightController = wastageWeightControllers[productId];
      final wastageReasonController = wastageReasonControllers[productId];
      final weightController = weightControllers[productId];
      
      final hasCountedQuantity = controller != null && controller.text.trim().isNotEmpty;
      final hasComment = commentController != null && commentController.text.trim().isNotEmpty;
      final hasWastage = wastageController != null && wastageController.text.trim().isNotEmpty;
      final hasWastageWeight = wastageWeightController != null && wastageWeightController.text.trim().isNotEmpty;
      final hasWastageReason = wastageReasonController != null && wastageReasonController.text.trim().isNotEmpty;
      final hasWeight = weightController != null && weightController.text.trim().isNotEmpty;
      
      // Check product unit to determine required fields
      final productUnit = (product?.unit ?? '').toLowerCase().trim();
      final isKgProduct = productUnit == 'kg';
      
      // Parse counted quantity and weight
      final countedQuantity = double.tryParse(controller?.text ?? '') ?? 0.0;
      final weightText = weightController?.text.trim() ?? '';
      final cleanWeightText = weightText.replaceAll(RegExp(r'[a-zA-Z]'), '').trim();
      final weight = double.tryParse(cleanWeightText) ?? 0.0;
      
      // For non-kg products: must have both count AND weight
      // UNLESS weight can be calculated from packaging_size
      // Check if packaging size exists and can be parsed (independent of count)
      bool weightCanBeCalculated = false;
      if (!isKgProduct) {
        // Check if packaging size can be parsed (regardless of count)
        weightCanBeCalculated = PackagingSizeParser.canCalculateWeight(product?.packagingSize);
      }
      
      // Validation: For non-kg products, need count AND (weight OR can calculate from packaging_size)
      bool hasRequiredData;
      if (isKgProduct) {
        // Kg products: weight is required (replaces quantity)
        hasRequiredData = hasWeight;
      } else {
        // Non-kg products: count is required, AND (weight OR can calculate from packaging_size)
        hasRequiredData = hasCountedQuantity && (hasWeight || weightCanBeCalculated);
      }
      
      // Skip if no required data AND no optional data (comment, wastage, wastage reason)
      // Allow entries with only wastage data (no stock count/weight update)
      if (!hasRequiredData && !hasComment && !hasWastage && !hasWastageWeight && !hasWastageReason) continue;
      
      // Initialize finalWeight - will be set based on conditions below
      double finalWeight = weight;
      
      // If only wastage data exists (no count/weight), allow it
      if (!hasRequiredData && (hasWastage || hasWastageWeight)) {
        // Entry is valid - only recording wastage, no stock update needed
        // Set defaults for count/weight to 0
        finalWeight = 0.0;
      }
      
      // If weight can be calculated but not provided, calculate it
      if (!isKgProduct && countedQuantity > 0 && weight <= 0 && weightCanBeCalculated) {
        final calculatedWeight = PackagingSizeParser.calculateWeightFromPackaging(
          count: countedQuantity.toInt(),
          packagingSize: product?.packagingSize,
        );
        if (calculatedWeight != null) {
          finalWeight = calculatedWeight;
          print('[STOCK_TAKE_LOGIC] Calculated weight for ${product?.name}: $countedQuantity ${productUnit} × ${product?.packagingSize} = ${calculatedWeight.toStringAsFixed(3)} kg');
        }
      }
      
      final currentStock = originalStock[productId] ?? 0.0;
      final comment = commentController?.text.trim() ?? '';
      final wastageText = wastageController?.text?.trim() ?? '';
      final cleanWastageText = wastageText.replaceAll(RegExp(r'[a-zA-Z]'), '').trim();
      final wastageQuantity = double.tryParse(cleanWastageText) ?? 0.0;
      final wastageWeightText = wastageWeightController?.text?.trim() ?? '';
      final cleanWastageWeightText = wastageWeightText.replaceAll(RegExp(r'[a-zA-Z]'), '').trim();
      final wastageWeight = double.tryParse(cleanWastageWeightText) ?? 0.0;
      final wastageReason = wastageReasonController?.text.trim() ?? '';
      
      final productName = product?.name ?? 'Unknown Product';
      
      print('[STOCK_TAKE_LOGIC] Including $productName (ID: $productId): counted=$countedQuantity, wastage=$wastageQuantity, wastageWeight=$wastageWeight, reason="$wastageReason", weight=$weight, comment="$comment"');
      
      entries.add({
        'product_id': productId,
        'product_name': productName,  // Include product name for easier debugging
        'counted_quantity': countedQuantity,
        'current_stock': currentStock,
        'wastage_quantity': wastageQuantity,
        'wastage_weight': wastageWeight,
        'wastage_reason': wastageReason,
        'weight': finalWeight,  // Use calculated weight if available
        'comment': comment,
      });
    }
    
    return entries;
  }
  
  /// Validate stock take entries and return validation errors
  /// Returns list of error messages, empty if valid
  /// 
  /// Note: If both count and weight are empty, entry is allowed if it has wastage data
  static List<String> validateStockTakeEntries({
    required List<Product> stockTakeProducts,
    required Map<int, TextEditingController> controllers,
    required Map<int, TextEditingController> weightControllers,
    required Map<int, TextEditingController> wastageControllers,
    required Map<int, TextEditingController> wastageWeightControllers,
  }) {
    final errors = <String>[];
    
    for (final product in stockTakeProducts) {
      final controller = controllers[product.id];
      final weightController = weightControllers[product.id];
      final wastageController = wastageControllers[product.id];
      final wastageWeightController = wastageWeightControllers[product.id];
      
      final productUnit = (product.unit ?? '').toLowerCase().trim();
      final isKgProduct = productUnit == 'kg';
      
      final hasCountedQuantity = controller != null && controller.text.trim().isNotEmpty;
      final hasWeight = weightController != null && weightController.text.trim().isNotEmpty;
      final hasWastageQuantity = wastageController != null && wastageController.text.trim().isNotEmpty;
      final hasWastageWeight = wastageWeightController != null && wastageWeightController.text.trim().isNotEmpty;
      
      final countedQuantity = double.tryParse(controller?.text ?? '') ?? 0.0;
      final weightText = weightController?.text.trim() ?? '';
      final cleanWeightText = weightText.replaceAll(RegExp(r'[a-zA-Z]'), '').trim();
      final weight = double.tryParse(cleanWeightText) ?? 0.0;
      
      // If both count and weight are empty, allow if wastage data exists
      if (!hasCountedQuantity && !hasWeight) {
        if (hasWastageQuantity || hasWastageWeight) {
          // Entry is valid - only recording wastage, no stock update needed
          continue;
        }
        // No data at all - skip validation (will be filtered out in buildStockTakeEntries)
        continue;
      }
      
      // Validate only if product count/weight data exists
      if (isKgProduct) {
        // Kg products: weight is required
        if (!hasWeight || weight <= 0) {
          errors.add('${product.name}: Weight is required for kg products');
        }
      } else {
        // Non-kg products: count is required
        if (!hasCountedQuantity || countedQuantity <= 0) {
          errors.add('${product.name}: Count is required for ${productUnit} products');
        } else {
          // Check if weight is provided OR can be calculated from packaging_size
          final weightCanBeCalculated = PackagingSizeParser.canCalculateWeight(product.packagingSize);
          if (!hasWeight && !weightCanBeCalculated) {
            errors.add('${product.name}: Weight is required for ${productUnit} products (or set packaging_size to calculate automatically)');
          }
        }
      }
    }
    
    return errors;
  }
  
  /// Validate that at least some data has been entered
  static bool hasAnyEntries({
    required List<Product> stockTakeProducts,
    required Map<int, TextEditingController> controllers,
    required Map<int, TextEditingController> commentControllers,
    required Map<int, TextEditingController> wastageControllers,
  }) {
    for (final product in stockTakeProducts) {
      final controller = controllers[product.id];
      final commentController = commentControllers[product.id];
      final wastageController = wastageControllers[product.id];
      
      final hasCountedQuantity = controller != null && controller.text.isNotEmpty;
      final hasComment = commentController != null && commentController.text.trim().isNotEmpty;
      final hasWastage = wastageController != null && wastageController.text.isNotEmpty;
      
      if (hasCountedQuantity || hasComment || hasWastage) {
        return true;
      }
    }
    return false;
  }
  
  /// Sort products alphabetically by name
  static List<Product> sortProducts(
    List<Product> products,
    Map<int, DateTime> addedTimestamps,
  ) {
    final sorted = List<Product>.from(products);
    
    // Sort alphabetically by product name
    sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    
    return sorted;
  }
  
  /// Filter products based on search query
  static List<Product> filterProducts(
    List<Product> products,
    String searchQuery,
  ) {
    if (searchQuery.isEmpty) return products;
    
    final query = searchQuery.toLowerCase();
    return products.where((product) {
      final name = product.name.toLowerCase();
      final sku = product.sku?.toLowerCase() ?? '';
      return name.contains(query) || sku.contains(query);
    }).toList();
  }
  
  /// Get products from all products that match search but aren't in stock take list
  static List<Product> getSearchResultsNotInList({
    required String searchQuery,
    required List<Product> allProducts,
    required List<Product> stockTakeProducts,
  }) {
    if (searchQuery.isEmpty) return [];
    
    final query = searchQuery.toLowerCase();
    final stockTakeIds = stockTakeProducts.map((p) => p.id).toSet();
    
    final results = allProducts.where((product) {
      final name = product.name.toLowerCase();
      final sku = product.sku?.toLowerCase() ?? '';
      final matchesSearch = name.contains(query) || sku.contains(query);
      final notInList = !stockTakeIds.contains(product.id);
      return matchesSearch && notInList;
    }).toList();
    
    // Sort by relevance: products starting with query first, then by alphabetical
    results.sort((a, b) {
      final aName = a.name.toLowerCase();
      final bName = b.name.toLowerCase();
      
      // Check if product name starts with the search query
      final aStartsWith = aName.startsWith(query);
      final bStartsWith = bName.startsWith(query);
      
      // Check if first word matches the search query
      final aFirstWord = aName.split(' ').first;
      final bFirstWord = bName.split(' ').first;
      final aFirstWordMatches = aFirstWord == query || aFirstWord.startsWith(query);
      final bFirstWordMatches = bFirstWord == query || bFirstWord.startsWith(query);
      
      // Priority 1: Exact match on first word
      if (aFirstWord == query && bFirstWord != query) return -1;
      if (bFirstWord == query && aFirstWord != query) return 1;
      
      // Priority 2: First word starts with query
      if (aFirstWordMatches && !bFirstWordMatches) return -1;
      if (bFirstWordMatches && !aFirstWordMatches) return 1;
      
      // Priority 3: Product name starts with query
      if (aStartsWith && !bStartsWith) return -1;
      if (bStartsWith && !aStartsWith) return 1;
      
      // Priority 4: Alphabetical order
      return aName.compareTo(bName);
    });
    
    return results;
  }
  
  /// Check if search query has no results - show create button when no search results found
  static bool shouldShowAddProductButton({
    required String searchQuery,
    required bool isLoadingProducts,
    required List<Product> searchResultsNotInList,
  }) {
    if (searchQuery.trim().isEmpty) return false;
    if (isLoadingProducts) return false;
    return searchResultsNotInList.isEmpty;
  }
  
  /// Calculate stock difference
  static double calculateDifference(double counted, double original) {
    return counted - original;
  }
  
  /// Format stock value for display
  static String formatStockValue(double value, {int decimals = 2}) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(decimals);
  }
}


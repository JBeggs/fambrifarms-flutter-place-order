import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../../models/product.dart';

/// Handles saving and loading of stock take progress
class BulkStockTakePersistence {
  static const String _progressFileName = 'bulk_stock_take_progress.json';
  
  /// Get the proper storage directory for the platform
  static Future<Directory> getStorageDirectory() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (e) {
      print('[PERSISTENCE] Error getting documents directory: $e');
      // Fallback to temporary directory
      return await getTemporaryDirectory();
    }
  }
  
  /// Save current progress to JSON file
  static Future<void> saveProgress({
    required List<Product> stockTakeProducts,
    required Map<int, TextEditingController> controllers,
    required Map<int, TextEditingController> commentControllers,
    required Map<int, TextEditingController> wastageControllers,
    required Map<int, TextEditingController> wastageReasonControllers,
    required Map<int, TextEditingController> weightControllers,
    required Map<int, DateTime> addedTimestamps,
    bool showSnackbar = false,
    BuildContext? context,
  }) async {
    try {
      final directory = await getStorageDirectory();
      final file = File('${directory.path}/$_progressFileName');
      
      print('[PERSISTENCE] Storage directory: ${directory.path}');
      print('[PERSISTENCE] Saving to: ${file.path}');
      
      final progressData = {
        'timestamp': DateTime.now().toIso8601String(),
        'products': stockTakeProducts.map((product) {
          final controller = controllers[product.id];
          final commentController = commentControllers[product.id];
          final wastageController = wastageControllers[product.id];
          final wastageReasonController = wastageReasonControllers[product.id];
          final weightController = weightControllers[product.id];
          
          return {
            'id': product.id,
            'name': product.name,
            'department': product.department,
            'unit': product.unit,
            'stockLevel': product.stockLevel,
            'minimumStock': product.minimumStock,
            'price': product.price,
            'enteredValue': controller?.text ?? '',
            'comment': commentController?.text ?? '',
            'wastageValue': wastageController?.text ?? '',
            'wastageReason': wastageReasonController?.text ?? '',
            'weight': weightController?.text ?? '',
            'addedTimestamp': addedTimestamps[product.id]?.millisecondsSinceEpoch,
          };
        }).toList(),
      };
      
      await file.writeAsString(jsonEncode(progressData));
      print('[PERSISTENCE] Progress saved to ${file.path}');
      
      if (context != null && context.mounted && showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Progress saved successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('[PERSISTENCE] Error saving progress: $e');
      if (context != null && context.mounted && showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error saving progress: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  /// Load saved progress from file
  static Future<Map<String, dynamic>?> loadSavedProgress() async {
    try {
      final directory = await getStorageDirectory();
      final file = File('${directory.path}/$_progressFileName');
      
      print('[PERSISTENCE] Storage directory: ${directory.path}');
      print('[PERSISTENCE] Loading from: ${file.path}');
      
      if (!await file.exists()) {
        print('[PERSISTENCE] No saved progress file found');
        return null;
      }
      
      final content = await file.readAsString();
      final progressData = jsonDecode(content) as Map<String, dynamic>;
      
      print('[PERSISTENCE] Found saved progress with ${(progressData['products'] as List).length} products');
      
      return progressData;
    } catch (e) {
      print('[PERSISTENCE] Error loading saved progress: $e');
      return null;
    }
  }
  
  /// Restore progress data into controllers
  static RestoreResult restoreProgress(Map<String, dynamic> progressData) {
    try {
      final savedProducts = progressData['products'] as List<dynamic>;
      final products = <Product>[];
      final entries = <int, Map<String, String>>{};
      
      for (final productData in savedProducts) {
        final product = Product(
          id: productData['id'],
          name: productData['name'],
          department: productData['department'],
          unit: productData['unit'],
          stockLevel: productData['stockLevel'],
          minimumStock: productData['minimumStock'],
          price: productData['price'],
        );
        
        products.add(product);
        
        entries[product.id] = {
          'enteredValue': productData['enteredValue'] ?? '',
          'comment': productData['comment'] ?? '',
          'wastageValue': productData['wastageValue'] ?? '',
          'wastageReason': productData['wastageReason'] ?? '',
          'weight': productData['weight'] ?? '',
          'addedTimestamp': productData['addedTimestamp']?.toString() ?? '',
        };
      }
      
      print('[PERSISTENCE] Restored ${savedProducts.length} products from saved progress');
      
      return RestoreResult(
        success: true,
        products: products,
        entries: entries,
        timestamp: progressData['timestamp'],
      );
    } catch (e) {
      print('[PERSISTENCE] Error restoring progress: $e');
      return RestoreResult(success: false);
    }
  }
  
  /// Clear saved progress file
  static Future<void> clearSavedProgress() async {
    try {
      final directory = await getStorageDirectory();
      final file = File('${directory.path}/$_progressFileName');
      
      if (await file.exists()) {
        await file.delete();
        print('[PERSISTENCE] Cleared saved progress file');
      }
    } catch (e) {
      print('[PERSISTENCE] Error clearing saved progress: $e');
    }
  }
  
  /// Alias for clearSavedProgress (for clarity in UI code)
  static Future<void> deleteProgressFile() async {
    await clearSavedProgress();
  }
  
  /// Check if saved progress exists
  static Future<bool> hasSavedProgress() async {
    try {
      final directory = await getStorageDirectory();
      final file = File('${directory.path}/$_progressFileName');
      return await file.exists();
    } catch (e) {
      print('[PERSISTENCE] Error checking for saved progress: $e');
      return false;
    }
  }
}

/// Result of restore operation
class RestoreResult {
  final bool success;
  final List<Product> products;
  final Map<int, Map<String, String>> entries;
  final String? timestamp;
  
  RestoreResult({
    required this.success,
    this.products = const [],
    this.entries = const {},
    this.timestamp,
  });
}


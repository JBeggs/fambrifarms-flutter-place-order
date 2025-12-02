import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Handles saving and loading of order items progress
class OrderItemsPersistence {
  static const String _progressFileName = 'order_items_progress.json';
  
  /// Get the proper storage directory for the platform
  static Future<Directory> getStorageDirectory() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (e) {
      print('[ORDER_PERSISTENCE] Error getting documents directory: $e');
      // Fallback to temporary directory
      return await getTemporaryDirectory();
    }
  }
  
  /// Save current progress for a specific order (messageId)
  /// Only saves changed items, tracks unprocessed items separately
  static Future<void> saveProgress({
    required String messageId,
    required Map<String, Map<String, dynamic>> selectedSuggestions,
    required Map<String, double> quantities,
    required Map<String, String> units,
    required Map<String, String> stockActions,
    required Map<String, bool> skippedItems,
    required Map<String, bool> useSourceProduct,
    required Map<String, Map<String, dynamic>> selectedSourceProducts,
    required Map<String, double> sourceQuantities,
    Map<String, String> sourceQuantityUnits = const {},
    required Map<String, String> editedOriginalText,
    List<String> unprocessedItems = const [],
    bool showSnackbar = false,
    BuildContext? context,
  }) async {
    try {
      final directory = await getStorageDirectory();
      final file = File('${directory.path}/$_progressFileName');
      
      print('[ORDER_PERSISTENCE] Storage directory: ${directory.path}');
      print('[ORDER_PERSISTENCE] Saving to: ${file.path}');
      
      // Load existing data or create new
      Map<String, dynamic> allOrdersData = {};
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          allOrdersData = jsonDecode(content) as Map<String, dynamic>;
        } catch (e) {
          print('[ORDER_PERSISTENCE] Error reading existing file, creating new: $e');
          allOrdersData = {};
        }
      }
      
      // Prepare data for this order
      final orderData = {
        'messageId': messageId,
        'timestamp': DateTime.now().toIso8601String(),
        'selectedSuggestions': selectedSuggestions.map((key, value) => MapEntry(key, value)),
        'quantities': quantities.map((key, value) => MapEntry(key, value)),
        'units': units.map((key, value) => MapEntry(key, value)),
        'stockActions': stockActions.map((key, value) => MapEntry(key, value)),
        'skippedItems': skippedItems.map((key, value) => MapEntry(key, value.toString())),
        'useSourceProduct': useSourceProduct.map((key, value) => MapEntry(key, value.toString())),
        'selectedSourceProducts': selectedSourceProducts.map((key, value) => MapEntry(key, value)),
        'sourceQuantities': sourceQuantities.map((key, value) => MapEntry(key, value)),
        'sourceQuantityUnits': sourceQuantityUnits.map((key, value) => MapEntry(key, value)),
        'editedOriginalText': editedOriginalText.map((key, value) => MapEntry(key, value)),
        'unprocessedItems': unprocessedItems,
      };
      
      print('[ORDER_PERSISTENCE] Saving ${selectedSuggestions.length} changed items, ${unprocessedItems.length} unprocessed items');
      
      // Store this order's data
      allOrdersData[messageId] = orderData;
      
      // Save all orders data
      await file.writeAsString(jsonEncode(allOrdersData));
      print('[ORDER_PERSISTENCE] Progress saved for order $messageId');
      
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
      print('[ORDER_PERSISTENCE] Error saving progress: $e');
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
  
  /// Load saved progress for a specific order (messageId)
  static Future<Map<String, dynamic>?> loadSavedProgress(String messageId) async {
    try {
      final directory = await getStorageDirectory();
      final file = File('${directory.path}/$_progressFileName');
      
      print('[ORDER_PERSISTENCE] Storage directory: ${directory.path}');
      print('[ORDER_PERSISTENCE] Loading from: ${file.path}');
      
      if (!await file.exists()) {
        print('[ORDER_PERSISTENCE] No saved progress file found');
        return null;
      }
      
      final content = await file.readAsString();
      final allOrdersData = jsonDecode(content) as Map<String, dynamic>;
      
      if (allOrdersData.containsKey(messageId)) {
        print('[ORDER_PERSISTENCE] Found saved progress for order $messageId');
        return allOrdersData[messageId] as Map<String, dynamic>;
      }
      
      print('[ORDER_PERSISTENCE] No saved progress found for order $messageId');
      return null;
    } catch (e) {
      print('[ORDER_PERSISTENCE] Error loading saved progress: $e');
      return null;
    }
  }
  
  /// Clear all saved progress (called when orders are moved to delivery)
  static Future<void> clearAllProgress() async {
    try {
      final directory = await getStorageDirectory();
      final file = File('${directory.path}/$_progressFileName');
      
      if (await file.exists()) {
        await file.delete();
        print('[ORDER_PERSISTENCE] Cleared all saved progress');
      }
    } catch (e) {
      print('[ORDER_PERSISTENCE] Error clearing saved progress: $e');
    }
  }
  
  /// Clear progress for a specific order (messageId)
  static Future<void> clearOrderProgress(String messageId) async {
    try {
      final directory = await getStorageDirectory();
      final file = File('${directory.path}/$_progressFileName');
      
      if (!await file.exists()) {
        return;
      }
      
      final content = await file.readAsString();
      final allOrdersData = jsonDecode(content) as Map<String, dynamic>;
      
      if (allOrdersData.containsKey(messageId)) {
        allOrdersData.remove(messageId);
        await file.writeAsString(jsonEncode(allOrdersData));
        print('[ORDER_PERSISTENCE] Cleared progress for order $messageId');
      }
    } catch (e) {
      print('[ORDER_PERSISTENCE] Error clearing order progress: $e');
    }
  }
}


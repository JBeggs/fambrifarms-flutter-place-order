import 'dart:io';
import 'package:flutter/material.dart';
import '../../../models/product.dart';
import '../widgets/bulk_stock_take_dialog.dart';
import '../pages/bulk_stock_take_page.dart';

class BulkStockTakeLauncher {
  /// Launch the appropriate bulk stock take interface based on platform
  /// - Desktop (Windows/macOS/Linux): Shows popup dialog
  /// - Mobile (Android/iOS): Navigates to full-screen page
  static void launch({
    required BuildContext context,
    required List<Product> products,
  }) {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // Desktop: Use popup dialog for better desktop UX
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => BulkStockTakeDialog(
          products: products,
        ),
      );
    } else {
      // Mobile/Android: Navigate to full-screen page for better mobile UX
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BulkStockTakePage(
            products: products,
          ),
        ),
      );
    }
  }

  /// Launch with dialog specifically (for backward compatibility)
  static void launchDialog({
    required BuildContext context,
    required List<Product> products,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BulkStockTakeDialog(
        products: products,
      ),
    );
  }

  /// Launch with full-screen page specifically
  static void launchPage({
    required BuildContext context,
    required List<Product> products,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BulkStockTakePage(
          products: products,
        ),
      ),
    );
  }
}

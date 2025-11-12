import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:place_order_final/features/inventory/utils/bulk_stock_take_launcher.dart';
import 'package:place_order_final/features/orders/mobile_orders_page.dart';
import 'package:place_order_final/features/messages/mobile_messages_page.dart';
import 'package:place_order_final/features/products/mobile_products_page.dart';
import 'package:place_order_final/providers/products_provider.dart';

class AndroidDashboardPage extends ConsumerWidget {
  const AndroidDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsState = ref.watch(productsProvider);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Farm Management',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.agriculture,
                      color: Colors.white,
                      size: 32,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Welcome to Farm Management',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Manage your stock and orders efficiently',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Quick Stats
              if (productsState.products.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        icon: Icons.inventory_2,
                        label: 'Total Products',
                        value: '${productsState.products.length}',
                        color: Colors.blue,
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.grey[300],
                      ),
                      _buildStatItem(
                        icon: Icons.trending_up,
                        label: 'In Stock',
                        value: '${productsState.products.where((p) => p.stockLevel > 0).length}',
                        color: Colors.green,
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.grey[300],
                      ),
                      _buildStatItem(
                        icon: Icons.warning,
                        label: 'Low Stock',
                        value: '${productsState.products.where((p) => p.stockLevel <= p.minimumStock).length}',
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),

              // Action Buttons
              // Stock Management Button
              _buildDashboardButton(
                context: context,
                title: 'Stock Management',
                subtitle: 'Perform bulk stock takes and inventory checks',
                icon: Icons.inventory,
                color: Colors.green,
                onTap: () => _navigateToStockTake(context, ref),
              ),

              const SizedBox(height: 20),

              // Place Orders Button (WhatsApp)
              _buildDashboardButton(
                context: context,
                title: 'Place Orders',
                subtitle: 'Process WhatsApp messages and create orders',
                icon: Icons.add_shopping_cart,
                color: Colors.orange,
                onTap: () => _navigateToPlaceOrders(context),
              ),

              const SizedBox(height: 20),

              // Orders Management Button  
              _buildDashboardButton(
                context: context,
                title: 'Orders Management',
                subtitle: 'View orders and reserved stock levels',
                icon: Icons.shopping_cart,
                color: Colors.blue,
                onTap: () => _navigateToOrders(context),
              ),

              const SizedBox(height: 20),

              // Products Management Button
              _buildDashboardButton(
                context: context,
                title: 'Products Management',
                subtitle: 'Manage products, stock, and recipes',
                icon: Icons.inventory_2,
                color: Colors.purple,
                onTap: () => _navigateToProducts(context),
              ),

              const SizedBox(height: 40),

              // Footer Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.phone_android,
                      color: Colors.grey[600],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Android Optimized Experience',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDashboardButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2), width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToStockTake(BuildContext context, WidgetRef ref) {
    final productsState = ref.read(productsProvider);
    
    if (productsState.products.isEmpty) {
      // Load products first if not loaded
      ref.read(productsProvider.notifier).loadProducts().then((_) {
        final updatedProducts = ref.read(productsProvider).products;
        BulkStockTakeLauncher.launch(
          context: context,
          products: updatedProducts,
        );
      });
    } else {
      BulkStockTakeLauncher.launch(
        context: context,
        products: productsState.products,
      );
    }
  }

  void _navigateToPlaceOrders(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MobileMessagesPage(),
      ),
    );
  }

  void _navigateToOrders(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MobileOrdersPage(),
      ),
    );
  }

  void _navigateToProducts(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MobileProductsPage(),
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:state_notifier/state_notifier.dart';
import '../models/product.dart';
import '../providers/customers_provider.dart';
import '../providers/products_provider.dart';
import '../providers/suppliers_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/orders_provider.dart';

// Dashboard overview data
class DashboardOverview {
  final BusinessMetrics businessMetrics;
  final List<AlertItem> alerts;
  final List<QuickAction> quickActions;
  final List<RecentActivity> recentActivities;

  const DashboardOverview({
    required this.businessMetrics,
    required this.alerts,
    required this.quickActions,
    required this.recentActivities,
  });
}

class BusinessMetrics {
  final int totalCustomers;
  final int activeCustomers;
  final int totalProducts;
  final int lowStockProducts;
  final int outOfStockProducts;
  final int totalSuppliers;
  final int activeSuppliers;
  final double totalBusinessValue;
  final double averageOrderValue;
  final int recentOrders;

  const BusinessMetrics({
    required this.totalCustomers,
    required this.activeCustomers,
    required this.totalProducts,
    required this.lowStockProducts,
    required this.outOfStockProducts,
    required this.totalSuppliers,
    required this.activeSuppliers,
    required this.totalBusinessValue,
    required this.averageOrderValue,
    required this.recentOrders,
  });

  // Business health indicators
  double get customerHealthScore {
    if (totalCustomers == 0) return 0.0;
    return (activeCustomers / totalCustomers) * 100;
  }

  double get stockHealthScore {
    if (totalProducts == 0) return 100.0;
    final healthyStock = totalProducts - lowStockProducts - outOfStockProducts;
    return (healthyStock / totalProducts) * 100;
  }

  double get supplierHealthScore {
    if (totalSuppliers == 0) return 0.0;
    return (activeSuppliers / totalSuppliers) * 100;
  }

  String get overallHealthStatus {
    final avgHealth = (customerHealthScore + stockHealthScore + supplierHealthScore) / 3;
    if (avgHealth >= 80) return 'Excellent';
    if (avgHealth >= 60) return 'Good';
    if (avgHealth >= 40) return 'Fair';
    return 'Needs Attention';
  }
}

class AlertItem {
  final String id;
  final AlertType type;
  final String title;
  final String message;
  final AlertPriority priority;
  final DateTime timestamp;
  final String? actionRoute;

  const AlertItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.priority,
    required this.timestamp,
    this.actionRoute,
  });
}

enum AlertType {
  stock,
  customer,
  supplier,
  order,
  system,
}

enum AlertPriority {
  low,
  medium,
  high,
  critical,
}

class QuickAction {
  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final String route;
  final int? badgeCount;

  const QuickAction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    this.badgeCount,
  });
}

class RecentActivity {
  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final ActivityType type;

  const RecentActivity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.type,
  });
}

enum ActivityType {
  customer,
  product,
  supplier,
  order,
  stock,
}

// Dashboard provider
class DashboardNotifier extends StateNotifier<AsyncValue<DashboardOverview>> {
  final Ref _ref;

  DashboardNotifier(this._ref) : super(const AsyncValue.loading()) {
    // Don't load data in constructor - let the UI trigger it
  }

  Future<void> loadDashboard() async {
    try {
      state = const AsyncValue.loading();

      // Load data from all providers first - but don't await during initialization
      final futures = [
        _ref.read(customersProvider.notifier).loadCustomers(),
        _ref.read(productsProvider.notifier).loadProducts(),
        _ref.read(suppliersProvider.notifier).loadSuppliers(),
        _ref.read(inventoryProvider.notifier).loadStockLevels(),
        _ref.read(ordersProvider.notifier).loadOrders(),
      ];
      
      await Future.wait(futures);

      // Get data from all providers
      final customersStats = _ref.read(customersStatsProvider);
      final productsStats = _ref.read(productsStatsProvider);
      final suppliersStats = _ref.read(suppliersStatsProvider);
      final lowStockProducts = _ref.read(lowStockProductsProvider);
      final outOfStockProducts = _ref.read(outOfStockProductsProvider);
      final inventoryState = _ref.read(inventoryProvider);
      final ordersState = _ref.read(ordersProvider);

      // Calculate inventory value using new products-based inventory
      final inventoryValue = inventoryState.products.fold(0.0, (sum, product) {
        return sum + (product.stockLevel * product.price);
      });

      // Calculate average order value
      final totalOrderValue = ordersState.orders.fold(0.0, (sum, order) => sum + (order.totalAmount ?? 0.0));
      final averageOrderValue = ordersState.orders.isNotEmpty 
          ? totalOrderValue / ordersState.orders.length 
          : 0.0;

      // Create business metrics
      final businessMetrics = BusinessMetrics(
        totalCustomers: customersStats['total'] ?? 0,
        activeCustomers: customersStats['active'] ?? 0,
        totalProducts: productsStats['total'] ?? 0,
        lowStockProducts: lowStockProducts.length,
        outOfStockProducts: outOfStockProducts.length,
        totalSuppliers: suppliersStats['total'] ?? 0,
        activeSuppliers: suppliersStats['active'] ?? 0,
        totalBusinessValue: inventoryValue + totalOrderValue,
        averageOrderValue: averageOrderValue,
        recentOrders: ordersState.orders.length,
      );

      // Generate alerts using combined low stock and out of stock products
      final stockAlerts = [...lowStockProducts, ...outOfStockProducts];
      final alerts = _generateAlerts(businessMetrics, lowStockProducts, outOfStockProducts, stockAlerts);

      // Generate quick actions
      final quickActions = _generateQuickActions(businessMetrics);

      // Generate recent activities
      final recentActivities = _generateRecentActivities(ordersState.orders, inventoryState.stockMovements);

      final overview = DashboardOverview(
        businessMetrics: businessMetrics,
        alerts: alerts,
        quickActions: quickActions,
        recentActivities: recentActivities,
      );

      state = AsyncValue.data(overview);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  List<AlertItem> _generateAlerts(BusinessMetrics metrics, List<dynamic> lowStock, List<dynamic> outOfStock, List<dynamic> inventoryAlerts) {
    final alerts = <AlertItem>[];
    final now = DateTime.now();

    // Stock alerts
    if (outOfStock.isNotEmpty) {
      alerts.add(AlertItem(
        id: 'out_of_stock',
        type: AlertType.stock,
        title: 'Products Out of Stock',
        message: '${outOfStock.length} products are completely out of stock',
        priority: AlertPriority.critical,
        timestamp: now,
        actionRoute: '/products',
      ));
    }

    if (lowStock.isNotEmpty) {
      alerts.add(AlertItem(
        id: 'low_stock',
        type: AlertType.stock,
        title: 'Low Stock Warning',
        message: '${lowStock.length} products are running low on stock',
        priority: AlertPriority.high,
        timestamp: now,
        actionRoute: '/products',
      ));
    }

    // Customer health alerts
    if (metrics.customerHealthScore < 60) {
      alerts.add(AlertItem(
        id: 'customer_health',
        type: AlertType.customer,
        title: 'Customer Activity Low',
        message: 'Only ${metrics.customerHealthScore.toStringAsFixed(1)}% of customers are active',
        priority: AlertPriority.medium,
        timestamp: now,
        actionRoute: '/customers',
      ));
    }

    // Supplier health alerts
    if (metrics.supplierHealthScore < 80) {
      alerts.add(AlertItem(
        id: 'supplier_health',
        type: AlertType.supplier,
        title: 'Supplier Review Needed',
        message: 'Some suppliers may need attention',
        priority: AlertPriority.low,
        timestamp: now,
        actionRoute: '/suppliers',
      ));
    }

    // Inventory system alerts - handle Product objects
    for (final alert in inventoryAlerts) {
      if (alert is Product) {
        // Handle Product objects (low stock/out of stock products)
        final isOutOfStock = alert.stockLevel <= 0;
        alerts.add(AlertItem(
          id: 'inventory_${alert.id}',
          type: AlertType.stock,
          title: isOutOfStock ? 'Out of Stock' : 'Low Stock',
          message: '${alert.name} - ${alert.stockStatusDisplay}',
          priority: isOutOfStock ? AlertPriority.high : AlertPriority.medium,
          timestamp: alert.lastUpdated ?? now,
          actionRoute: '/inventory',
        ));
      } else if (alert is Map<String, dynamic>) {
        // Handle Map objects (legacy inventory alerts)
        alerts.add(AlertItem(
          id: 'inventory_${alert['id'] ?? DateTime.now().millisecondsSinceEpoch}',
          type: AlertType.stock,
          title: alert['title'] ?? 'Inventory Alert',
          message: alert['message'] ?? 'Check inventory system',
          priority: _getAlertPriority(alert['severity']),
          timestamp: DateTime.tryParse(alert['created_at'] ?? '') ?? now,
          actionRoute: '/inventory',
        ));
      }
    }

    return alerts;
  }

  AlertPriority _getAlertPriority(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'high':
      case 'critical':
        return AlertPriority.critical;
      case 'medium':
        return AlertPriority.high;
      case 'low':
        return AlertPriority.medium;
      default:
        return AlertPriority.low;
    }
  }

  List<QuickAction> _generateQuickActions(BusinessMetrics metrics) {
    return [
      QuickAction(
        id: 'customers',
        title: 'Manage Customers',
        subtitle: '${metrics.totalCustomers} customers',
        icon: 'people',
        route: '/customers',
        badgeCount: metrics.totalCustomers - metrics.activeCustomers > 0 
            ? metrics.totalCustomers - metrics.activeCustomers 
            : null,
      ),
      QuickAction(
        id: 'products',
        title: 'Product Catalog',
        subtitle: '${metrics.totalProducts} products',
        icon: 'inventory',
        route: '/products',
        badgeCount: metrics.lowStockProducts + metrics.outOfStockProducts > 0 
            ? metrics.lowStockProducts + metrics.outOfStockProducts 
            : null,
      ),
      QuickAction(
        id: 'suppliers',
        title: 'Supplier Network',
        subtitle: '${metrics.totalSuppliers} suppliers',
        icon: 'business',
        route: '/suppliers',
      ),
      QuickAction(
        id: 'inventory',
        title: 'Inventory Management',
        subtitle: 'Stock levels & alerts',
        icon: 'warehouse',
        route: '/inventory',
      ),
      QuickAction(
        id: 'whatsapp',
        title: 'WhatsApp Orders',
        subtitle: 'Process messages',
        icon: 'message',
        route: '/messages',
      ),
    ];
  }

  List<RecentActivity> _generateRecentActivities(List<dynamic> orders, List<Map<String, dynamic>> stockMovements) {
    final activities = <RecentActivity>[];
    final now = DateTime.now();

    // Add recent orders
    for (final order in orders.take(3)) {
      activities.add(RecentActivity(
        id: 'order_${order.id}',
        title: 'Order ${order.orderNumber ?? 'N/A'}',
        subtitle: 'Status: ${order.status} • R${(order.totalAmount ?? 0.0).toStringAsFixed(2)}',
        timestamp: order.createdAt,
        type: ActivityType.customer,
      ));
    }

    // Add recent stock movements
    for (final movement in stockMovements.take(3)) {
      final isIncrease = (movement['quantity'] as num?) != null && (movement['quantity'] as num) > 0;
      activities.add(RecentActivity(
        id: 'stock_${movement['id'] ?? DateTime.now().millisecondsSinceEpoch}',
        title: '${movement['product_name'] ?? 'Product'} Stock ${isIncrease ? 'Added' : 'Reduced'}',
        subtitle: '${isIncrease ? '+' : ''}${movement['quantity'] ?? 0} units',
        timestamp: DateTime.tryParse(movement['created_at'] ?? '') ?? now,
        type: ActivityType.stock,
      ));
    }

    // Sort by timestamp (newest first)
    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Return top 5 activities
    return activities.take(5).toList();
  }

  Future<void> refresh() async {
    await loadDashboard();
  }
}

// Dashboard provider
final dashboardProvider = StateNotifierProvider<DashboardNotifier, AsyncValue<DashboardOverview>>((ref) {
  return DashboardNotifier(ref);
});

// Convenience providers
final businessMetricsProvider = Provider<BusinessMetrics?>((ref) {
  final dashboardState = ref.watch(dashboardProvider);
  return dashboardState.maybeWhen(
    data: (overview) => overview.businessMetrics,
    orElse: () => null,
  );
});

final alertsProvider = Provider<List<AlertItem>>((ref) {
  final dashboardState = ref.watch(dashboardProvider);
  return dashboardState.maybeWhen(
    data: (overview) => overview.alerts,
    orElse: () => [],
  );
});

final quickActionsProvider = Provider<List<QuickAction>>((ref) {
  final dashboardState = ref.watch(dashboardProvider);
  return dashboardState.maybeWhen(
    data: (overview) => overview.quickActions,
    orElse: () => [],
  );
});

final recentActivitiesProvider = Provider<List<RecentActivity>>((ref) {
  final dashboardState = ref.watch(dashboardProvider);
  return dashboardState.maybeWhen(
    data: (overview) => overview.recentActivities,
    orElse: () => [],
  );
});


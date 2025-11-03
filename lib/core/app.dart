import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/karl_login_page.dart';
import '../features/auth/karl_auth_provider.dart';
import '../features/karl_dashboard/karl_dashboard_page.dart';
import '../features/customers/customers_page.dart';
import '../features/customers/customer_detail_page.dart';
import '../features/customers/customer_orders_page.dart';
import '../features/products/products_page.dart';
import '../features/products/product_detail_page.dart';
import '../features/suppliers/suppliers_page.dart';
import '../features/suppliers/supplier_detail_page.dart';
import '../features/procurement/procurement_page.dart';
import '../features/landing/landing_page.dart';
import '../features/loading/loading_page.dart';
import '../features/messages/messages_page.dart';
import '../features/orders/orders_page.dart';
import '../features/pricing/pricing_dashboard_page.dart';
import '../features/inventory/inventory_page.dart';
import '../features/inventory/bulk_stock_take_page.dart';
import '../features/dashboard/dashboard_page.dart';
import 'professional_theme.dart';

final routerProvider = Provider.family<GoRouter, String?>((ref, initialRoute) {
  // Watch for auth state changes to trigger router refresh
  ref.watch(karlAuthProvider);
  
  return GoRouter(
    initialLocation: initialRoute ?? '/loading',
    redirect: (context, state) {
      final isAuthenticated = ref.read(isAuthenticatedProvider);
      final isLoading = ref.read(authLoadingProvider);
      
      // print('[ROUTER] Current path: ${state.uri.path}, isAuthenticated: $isAuthenticated, isLoading: $isLoading');
      
      // Show loading screen while checking auth
      if (isLoading && state.uri.path != '/loading') {
        // print('[ROUTER] Redirecting to loading');
        return '/loading';
      }
      
      // After loading is complete, redirect appropriately
      if (!isLoading) {
        // Allow direct access to bulk stock take WITHOUT authentication
        if (state.uri.path == '/bulk-stock-take') {
          return null; // Allow access regardless of auth status
        }
        
        if (!isAuthenticated && state.uri.path != '/login') {
          // print('[ROUTER] Redirecting to login');
          return '/login';
        }
        
        if (isAuthenticated && (state.uri.path == '/login' || state.uri.path == '/' || state.uri.path == '/loading')) {
          // print('[ROUTER] Redirecting to karl-dashboard');
          return '/karl-dashboard';
        }
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LandingPage(),
      ),
      GoRoute(
        path: '/loading',
        builder: (context, state) => const LoadingPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const KarlLoginPage(),
      ),
      GoRoute(
        path: '/karl-dashboard',
        builder: (context, state) => const KarlDashboardPage(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
      // Legacy routes (keep for existing functionality)
      GoRoute(
        path: '/messages',
        builder: (context, state) => const MessagesPage(),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const OrdersPage(),
      ),
      GoRoute(
        path: '/pricing',
        builder: (context, state) => const PricingDashboardPage(),
      ),
      // Karl's customer management
      GoRoute(
        path: '/customers',
        builder: (context, state) => const CustomersPage(),
      ),
      GoRoute(
        path: '/customers/:id',
        builder: (context, state) {
          final customerId = int.tryParse(state.pathParameters['id'] ?? '');
          if (customerId == null) {
            return const Scaffold(
              body: Center(child: Text('Invalid customer ID')),
            );
          }
          return CustomerDetailPage(customerId: customerId);
        },
      ),
      GoRoute(
        path: '/customers/:id/orders',
        builder: (context, state) {
          final customerId = int.tryParse(state.pathParameters['id'] ?? '');
          if (customerId == null) {
            return const Scaffold(
              body: Center(child: Text('Invalid customer ID')),
            );
          }
          return CustomerOrdersPage(customerId: customerId);
        },
      ),
      GoRoute(
        path: '/products',
        builder: (context, state) => const ProductsPage(),
      ),
      GoRoute(
        path: '/products/:id',
        builder: (context, state) {
          final productId = int.tryParse(state.pathParameters['id'] ?? '');
          if (productId == null) {
            return const Scaffold(
              body: Center(child: Text('Invalid product ID')),
            );
          }
          return ProductDetailPage(productId: productId);
        },
      ),
            GoRoute(
              path: '/suppliers',
              builder: (context, state) => const SuppliersPage(),
            ),
            GoRoute(
              path: '/suppliers/:id',
              builder: (context, state) {
                final supplierId = int.tryParse(state.pathParameters['id'] ?? '');
                if (supplierId == null) {
                  return const Scaffold(
                    body: Center(child: Text('Invalid supplier ID')),
                  );
                }
                return SupplierDetailPage(supplierId: supplierId);
              },
            ),
            GoRoute(
              path: '/procurement',
              builder: (context, state) => const ProcurementPage(),
            ),
            GoRoute(
              path: '/inventory',
              builder: (context, state) => const InventoryPage(),
            ),
            GoRoute(
              path: '/bulk-stock-take',
              builder: (context, state) => const BulkStockTakePage(),
            ),
          ],
        );
      });

class PlaceOrderApp extends ConsumerWidget {
  final String? initialRoute;
  
  const PlaceOrderApp({super.key, this.initialRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider(initialRoute));
    
    return MaterialApp.router(
      title: 'Fambri Farms Management',
      theme: ProfessionalTheme.theme,
      darkTheme: ProfessionalTheme.theme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

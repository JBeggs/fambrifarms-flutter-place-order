import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/karl_login_page.dart';
import '../features/auth/karl_auth_provider.dart';
import '../features/karl_dashboard/karl_dashboard_page.dart';
import '../features/customers/customers_page.dart';
import '../features/products/products_page.dart';
import '../features/suppliers/suppliers_page.dart';
import '../features/procurement/procurement_page.dart';
import '../features/landing/landing_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/messages/messages_page.dart';
import '../features/orders/orders_page.dart';
import '../features/pricing/pricing_dashboard_page.dart';
import 'theme.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthenticated = ref.read(isAuthenticatedProvider);
      final isLoading = ref.read(authLoadingProvider);
      
      // Don't redirect while loading
      if (isLoading) return null;
      
      // If not authenticated and not on login page, redirect to login
      if (!isAuthenticated && state.location != '/login') {
        return '/login';
      }
      
      // If authenticated and on login page, redirect to dashboard
      if (isAuthenticated && state.location == '/login') {
        return '/karl-dashboard';
      }
      
      // If authenticated and on root, redirect to dashboard
      if (isAuthenticated && state.location == '/') {
        return '/karl-dashboard';
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LandingPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const KarlLoginPage(),
      ),
      GoRoute(
        path: '/karl-dashboard',
        builder: (context, state) => const KarlDashboardPage(),
      ),
      // Legacy routes (keep for existing functionality)
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
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
        path: '/products',
        builder: (context, state) => const ProductsPage(),
      ),
            GoRoute(
              path: '/suppliers',
              builder: (context, state) => const SuppliersPage(),
            ),
            GoRoute(
              path: '/procurement',
              builder: (context, state) => const ProcurementPage(),
            ),
          ],
        );
      });

class PlaceOrderApp extends ConsumerWidget {
  const PlaceOrderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'Fambri Farms Management',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
